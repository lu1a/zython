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
    const func_scope = count_func_scope(line.items);
    var tokenized_line = std.ArrayList([]u8).init(allocator);
    defer tokenized_line.deinit();
    try tokenized_line.append(line.items);
    std.debug.print("scope in line {s}: {d}\n", .{ tokenized_line.items[0], func_scope });
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
