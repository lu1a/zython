const std = @import("std");

const MAX_TOKENS_PER_LINE: usize = 48;
const MAX_CHARS_PER_TOKEN: usize = 128;

const number_chars = "0123456789.";
const grouping_chars = "()[]{},";
const operation_chars = " :=+-*/%";
const special_chars = grouping_chars ++ operation_chars;

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
        // Clear the line and token list so we can reuse them.
        defer line.clearRetainingCapacity();
        var token_list: [MAX_TOKENS_PER_LINE]Token = undefined;
        line_no += 1;

        tokenize_line(&line, &token_list);
        for (token_list) |token| {
            std.debug.print("{s}  ", .{token.value});
        }
        std.debug.print("\n", .{});
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

const TokenType = enum { grouping, id, operation, number, string };
const Token = struct {
    value: [MAX_CHARS_PER_TOKEN]u8,
    type: TokenType,
};

fn tokenize_line(line: *std.ArrayList(u8), tokenized_line: *[MAX_TOKENS_PER_LINE]Token) void {
    if (line.items.len == 0) {
        return;
    }

    var token_list_idx: usize = 0;
    var i: usize = 0;
    while (i < line.items.len) {
        const result = find_next_token(line.items[i..]);
        if (result.walked_to_idx > 0) {
            i += result.walked_to_idx;
        } else {
            i += 1;
        }
        tokenized_line[token_list_idx] = result.token;
        token_list_idx += 1;
    }
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
                var val: [128]u8 = undefined;
                std.mem.copyForwards(u8, &val, line[token_start_idx..(how_far_walked + 1)]);
                return .{ .token = .{ .value = val, .type = TokenType.string }, .walked_to_idx = how_far_walked + 1 };
            }
        }
    }

    for (grouping_chars) |special_char| {
        if (line[token_start_idx] == special_char) {
            var val: [128]u8 = undefined;
            std.mem.copyForwards(u8, &val, line[token_start_idx..(how_far_walked + 1)]);
            return .{ .token = .{ .value = val, .type = TokenType.grouping }, .walked_to_idx = how_far_walked + 1 };
        }
    }
    // When token is a primitive operation
    for (operation_chars) |special_char| {
        if (line[token_start_idx] == special_char) {
            var val: [128]u8 = undefined;
            std.mem.copyForwards(u8, &val, line[token_start_idx..(how_far_walked + 1)]);
            return .{ .token = .{ .value = val, .type = TokenType.operation }, .walked_to_idx = how_far_walked + 1 };
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
        var val: [128]u8 = undefined;
        std.mem.copyForwards(u8, &val, line[token_start_idx..how_far_walked]);
        return .{ .token = .{ .value = val, .type = TokenType.number }, .walked_to_idx = how_far_walked };
    }
    how_far_walked = token_start_idx;

    // Else token is a variable name
    while (how_far_walked < line.len) : (how_far_walked += 1) {
        for (special_chars) |special_char| {
            if (line[how_far_walked] == special_char) {
                var val: [128]u8 = undefined;
                std.mem.copyForwards(u8, &val, line[token_start_idx..how_far_walked]);
                return .{ .token = .{ .value = val, .type = TokenType.id }, .walked_to_idx = how_far_walked };
            }
        }
    }

    var val: [128]u8 = undefined;
    std.mem.copyForwards(u8, &val, line[token_start_idx..line.len]);
    return .{ .token = .{ .value = val, .type = TokenType.id }, .walked_to_idx = how_far_walked };
}
