const std = @import("std");
const testing = std.testing;
const lex = @import("lexer.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    if (std.os.argv.len != 2) {
        std.debug.print("Please pass a TOML file as the second argument", .{});
    }

    var gpa = std.heap.page_allocator;

    var f = try std.fs.openFileAbsoluteZ(std.os.argv[1], .{});
    defer f.close();

    const contents = try f.reader().readAllAlloc(gpa, 5 * 1024 * 1024);
    defer gpa.free(contents);

    const lexer = parser.Lexer{ .real = try lex.Lexer.init(gpa, contents) };
    var p = try parser.Parser.init(gpa, lexer);
    defer p.deinit();

    var table = p.parse() catch |err| {
        std.debug.print("error parsing {s}: {}\n", .{ std.os.argv[1], err });
        std.debug.print("{?}\n", .{p.diag});
        return err;
    };
    defer table.deinit(gpa);

    var actual_al = std.ArrayList(u8).init(gpa);
    defer actual_al.deinit();

    var json_writer = std.json.writeStreamArbitraryDepth(
        gpa,
        actual_al.writer(),
        .{ .whitespace = .indent_4 },
    );
    defer json_writer.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const integration = @import("integration_tests.zig");
    var actual_json = try integration.tableToJson(arena.allocator(), &table);
    try actual_json.jsonStringify(&json_writer);

    std.debug.print("{s}", .{actual_al.items});
}
