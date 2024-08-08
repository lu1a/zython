const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
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

        std.debug.print("{d}\t{s}\n", .{ line_no, line.items });
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
                std.debug.print("{d}\t{s}\n", .{ line_no, line.items });
            }
        },
        else => return err, // Propagate error
    }

    std.debug.print("Total lines: {d}\n", .{line_no});

    tokenize_line();
    tokens_into_ast();
    ast_into_action_tree();
    execute_action_tree();
}

fn tokenize_line() void {}

fn tokens_into_ast() void {}

fn ast_into_action_tree() void {}

fn execute_action_tree() void {}
