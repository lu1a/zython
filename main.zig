const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Please provide a python file. Shell not yet available.\n", .{});
        return;
    }

    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();
    var line_no: usize = 0;
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();
        line_no += 1;

        var result = try tokenize_line(&line, allocator);
        defer result.tokenized_line.deinit();

        var ast = std.ArrayList(ASTNode).init(allocator);
        defer ast.deinit();
        try tokens_into_ast(&result.tokenized_line, &ast, 0);
        for (ast.items) |node| {
            std.debug.print("{d}:{s}:'{s}' ", .{ node.level, @tagName(node.token.type), node.token.value });
        }
        std.debug.print("\n", .{});

        ast_into_action_tree();
        execute_action_tree();
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
                std.debug.print("{s}\n", .{line.items});
            }
        },
        else => return err, // Propagate error
    }
}

const TokenType = enum { grouping, id, operation, number, string, unknown };
const Token = struct {
    value: []u8,
    type: TokenType,
};

const ASTNode = struct {
    level: usize,
    token: Token,
};

fn tokenize_line(line: *std.ArrayList(u8), allocator: std.mem.Allocator) !struct { tokenized_line: std.ArrayList(Token), func_scope: usize } {
    var tokenized_line = std.ArrayList(Token).init(allocator);
    const func_scope = count_func_scope(line.items);
    if (line.items.len == 0) {
        return .{ .tokenized_line = tokenized_line, .func_scope = func_scope };
    }

    var i: usize = 0;
    while (i < line.items.len) {
        const result = find_next_token(line.items[i..]);
        if (result.walked_to_idx > 0) {
            i += result.walked_to_idx;
        } else {
            i += 1;
        }
        try tokenized_line.append(result.token);
    }
    return .{ .tokenized_line = tokenized_line, .func_scope = func_scope };
}

fn find_next_token(line: []u8) struct { token: Token, walked_to_idx: usize } {
    var token_start_idx: usize = 0;
    var how_far_walked: usize = 0;
    for (line) |char| {
        if (char == ' ') {
            token_start_idx += 1;
            how_far_walked += 1;
        } else {
            break;
        }
    }

    // When token is a string
    if (line[how_far_walked] == '"' or line[how_far_walked] == '\'') {
        how_far_walked += 1;
        while (how_far_walked < line.len) : (how_far_walked += 1) {
            if (line[how_far_walked] == '"' or line[how_far_walked] == '\'') {
                return .{ .token = .{ .value = line[token_start_idx .. how_far_walked + 1], .type = TokenType.string }, .walked_to_idx = how_far_walked + 1 };
            }
        }
    }

    const number_chars = "0123456789.";
    const grouping_chars = "()[]{},";
    const operation_chars = " :=+-*/%";
    const special_chars = grouping_chars ++ operation_chars;

    for (grouping_chars) |special_char| {
        if (line[token_start_idx] == special_char) {
            return .{ .token = .{ .value = line[token_start_idx .. how_far_walked + 1], .type = TokenType.grouping }, .walked_to_idx = how_far_walked + 1 };
        }
    }
    // When token is a primitive operation
    for (operation_chars) |special_char| {
        if (line[token_start_idx] == special_char) {
            return .{ .token = .{ .value = line[token_start_idx .. how_far_walked + 1], .type = TokenType.operation }, .walked_to_idx = how_far_walked + 1 };
        }
    }

    // Test if token is a number and reset if not
    var is_token_number = false;
    var is_char_part_of_a_number = false;
    while (how_far_walked < line.len) : (how_far_walked += 1) {
        is_char_part_of_a_number = false;
        is_token_number = false;
        for (number_chars) |number_char| {
            if (line[how_far_walked] == number_char) {
                is_char_part_of_a_number = true;
                break;
            }
        }
        if (!is_char_part_of_a_number) {
            is_token_number = false;
            for (special_chars) |special_char| {
                if (line[how_far_walked] == special_char) {
                    is_token_number = true;
                }
            }
            break;
        } else {
            is_token_number = true;
        }
    }
    if (is_token_number) {
        return .{ .token = .{ .value = line[token_start_idx..how_far_walked], .type = TokenType.number }, .walked_to_idx = how_far_walked };
    }
    how_far_walked = token_start_idx;

    // Else token is a variable name
    while (how_far_walked < line.len) : (how_far_walked += 1) {
        for (special_chars) |special_char| {
            if (line[how_far_walked] == special_char) {
                return .{ .token = .{ .value = line[token_start_idx..how_far_walked], .type = TokenType.id }, .walked_to_idx = how_far_walked };
            }
        }
    }

    return .{ .token = .{ .value = line[token_start_idx..line.len], .type = TokenType.id }, .walked_to_idx = how_far_walked };
}

fn count_func_scope(line: []u8) usize {
    var starting_spaces_count: usize = 0;
    for (line) |char| {
        if (char == ' ') {
            starting_spaces_count += 1;
        } else {
            break;
        }
    }
    return @divFloor(starting_spaces_count, 4);
}

fn tokens_into_ast(tokens: *std.ArrayList(Token), ast: *std.ArrayList(ASTNode), idx: usize) !void {
    if (idx >= tokens.items.len) return;

    try ast.append(.{ .level = 0, .token = tokens.items[idx] });
    try tokens_into_ast(tokens, ast, idx + 1);
}

fn ast_into_action_tree() void {}

fn execute_action_tree() void {}
