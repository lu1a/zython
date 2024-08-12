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

        std.debug.print("{s}\n", .{line.items});

        try tokenize_line(&line, allocator);
        tokens_into_ast();
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

fn tokenize_line(line: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    if (line.items.len == 0) {
        return;
    }
    const func_scope = count_func_scope(line.items);
    var tokenized_line = std.ArrayList([]u8).init(allocator);
    defer tokenized_line.deinit();

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
    std.debug.print("{s}: >> scope level {d}\n", .{ tokenized_line.items, func_scope });
}

fn find_next_token(line: []u8) struct { token: []u8, token_type: usize, walked_to_idx: usize } {
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
                return .{ .token = line[token_start_idx .. how_far_walked + 1], .token_type = 0, .walked_to_idx = how_far_walked + 1 };
            }
        }
    }

    const special_chars = " :(),[]{}=+-*/%";

    // When token is itself a special char
    for (special_chars) |special_char| {
        if (line[token_start_idx] == special_char) {
            return .{ .token = line[token_start_idx .. how_far_walked + 1], .token_type = 1, .walked_to_idx = how_far_walked + 1 };
        }
    }

    // When token is a var or other literal
    while (how_far_walked < line.len) : (how_far_walked += 1) {
        for (special_chars) |special_char| {
            if (line[how_far_walked] == special_char) {
                return .{ .token = line[token_start_idx..how_far_walked], .token_type = 2, .walked_to_idx = how_far_walked };
            }
        }
    }

    return .{ .token = line[token_start_idx..line.len], .token_type = 3, .walked_to_idx = how_far_walked };
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

fn tokens_into_ast() void {}

fn ast_into_action_tree() void {}

fn execute_action_tree() void {}
