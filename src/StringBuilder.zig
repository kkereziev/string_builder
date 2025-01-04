const std = @import("std");
const Error = @import("./error.zig").Error;
// const testing = std.testing;

const Self = @This();

_alloc: std.mem.Allocator,
_pos: usize,
_buf: []u8,

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        ._pos = 0,
        ._alloc = alloc,
        ._buf = &[_]u8{},
    };
}

pub fn initWithCapacity(alloc: std.mem.Allocator, size: usize) !Self {
    if (size == 0) {
        return Error.ZeroSize;
    }

    const buf = try alloc.alloc(u8, size);

    return .{
        ._pos = 0,
        ._alloc = alloc,
        ._buf = buf,
    };
}

pub fn deinit(self: *Self) void {
    self._alloc.free(self._buf);
}

pub fn write(self: *Self, str: []const u8) !void {
    try self.ensureCapacity(str.len);

    const end_pos = self._pos + str.len;
    @memcpy(self._buf[self._pos..end_pos], str);

    self._pos += str.len;
}

pub fn writeByte(self: *Self, b: u8) !void {
    try self.ensureCapacity(1);

    self._buf[self._pos] = b;
    self._pos += 1;
}

pub fn string(self: *Self) []const u8 {
    return self._buf[0..self._pos];
}

pub fn len(self: *Self) usize {
    return self._pos;
}

inline fn ensureCapacity(self: *Self, required_capacity: usize) !void {
    const free_capacity = self.freeCapacity();

    if (free_capacity >= required_capacity) {
        return;
    }

    const new_capacity = self.calculateNewCapacity(required_capacity);

    const is_resized = self._alloc.resize(self._buf, new_capacity);

    if (!is_resized) {
        const old_buffer = self._buf;

        const new_buffer = try self._alloc.alloc(u8, new_capacity);

        @memcpy(new_buffer[0..self._pos], old_buffer[0..self._pos]);

        self._alloc.free(old_buffer);

        self._buf = new_buffer;
    }
}

inline fn freeCapacity(self: *Self) usize {
    return self._buf.len - self.len();
}

inline fn calculateNewCapacity(self: *Self, required_capacity: usize) usize {
    var new_capacity = self._buf.len;
    while (true) {
        new_capacity +|= new_capacity / 2 + 8;
        if (new_capacity >= required_capacity) break;
    }

    return new_capacity;
}

const t = std.testing;
const assert = std.debug.assert;

test {
    std.testing.refAllDecls(@This());
}

test "ensure error on provided 0 initial capacity" {
    const err = initWithCapacity(std.testing.allocator, 0);

    assert(err == Error.ZeroSize);
}

test "writeByte with no resizing" {
    var sb = try initWithCapacity(std.testing.allocator, 10);
    defer sb.deinit();

    const buf_pointer = sb._buf.ptr;

    try sb.writeByte('H');
    try sb.writeByte('e');
    try sb.writeByte('l');
    try sb.writeByte('l');
    try sb.writeByte('o');

    try t.expectEqualStrings("Hello", sb.string());
    assert(sb._pos == 5);
    assert(sb._buf.len == 10);
    assert(buf_pointer == sb._buf.ptr);
}

test "write with no resizing" {
    var sb = try initWithCapacity(std.testing.allocator, 5);
    defer sb.deinit();

    try sb.write("Hello");

    try t.expectEqualStrings("Hello", sb.string());
    assert(sb._pos == 5);
}

test "write with resize" {
    var sb = try initWithCapacity(std.testing.allocator, 3);
    defer sb.deinit();

    try sb.write("Hello World");

    assert(sb._pos == 11);
    assert(sb._buf.len == 12);
    try t.expectEqualStrings("Hello World", sb.string());
}

test "writeByte with resize" {
    var sb = try initWithCapacity(std.testing.allocator, 2);
    defer sb.deinit();

    try sb.writeByte('1');
    try sb.writeByte('2');
    try sb.writeByte('3');

    assert(sb._pos == 3);
    assert(sb._buf.len == 11);
    try t.expectEqualStrings("123", sb.string());
}

test "init with write" {
    var sb = init(std.testing.allocator);
    defer sb.deinit();

    try sb.write("abcwedasdasdawqewqewq");

    assert(sb._pos == 21);
    assert(sb._buf.len == 38);
    try t.expectEqualStrings("abcwedasdasdawqewqewq", sb.string());
}
