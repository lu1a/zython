const std = @import("std");

pub fn main() !void {
    var arr = [6]u8{ 10, 7, 8, 9, 1, 5 };
    _ = &arr;
    const n = arr.len;

    quickSort(&arr, 0, n - 1);

    std.debug.print("Sorted array:\n", .{});
    for (arr) |el| {
        std.debug.print("{d} ", .{el});
    }
    std.debug.print("\n", .{});
}

fn quickSort(arr: *[6]u8, low: usize, high: usize) void {
    if (low < high) {
        const pi = partition(arr, low, high);

        quickSort(arr, low, pi - 1);
        quickSort(arr, pi + 1, high);
    }
}

fn partition(arr: *[6]u8, low: usize, high: usize) usize {
    const pivot = arr[high];

    var i: ?usize = null;
    if (low > 0) {
        i = (low - 1);
    }
    var j = low;
    while (j <= high) : (j += 1) {
        if (arr[j] < pivot) {
            if (i == null) {
                i = 0;
            } else {
                i = i.? + 1;
            }
            swap(&arr[i.?], &arr[j]);
        }
    }
    swap(&arr[i.? + 1], &arr[high]);
    return (i.? + 1);
}

fn swap(p1: *u8, p2: *u8) void {
    const temp = p1.*;
    p1.* = p2.*;
    p2.* = temp;
}
