const std = @import("std");
const imui = @import("imui");
const ray = @import("raylib");

pub fn main() !void {
    try imui.openWindow(1280, 720, "Window");
    defer imui.closeWindow();

    const my_font = try imui.loadFont("C:\\Windows\\Fonts\\Arial.ttf");
    defer ray.unloadFont(my_font);
    imui.setFont(my_font);

    //imui.registerComponent(imui.Component());

    //var is_open: bool = false;
    //var selected: usize = 0;

    while (!ray.windowShouldClose()) {
        imui.startFrame();

        imui.buttonNew();

        //_ = imui.commandButton(.{ .x = 100, .y = 100 }, .{ .x = 100, .y = 100 }, "test");

        //imui.commandDropdown(.{ .x = 300, .y = 100 }, .{ .x = 100, .y = 30 }, &is_open, &[_][]const u8{"test", "tes2"}, &selected);

        //imui.container("main", .{ .child_axis = .vertical }, imui.percent(100, 100))({
        //    imui.container("search-tab", .{ .child_axis = .horizontal }, imui.percent(100, 10))({
        //        // TODO: add input field
//
        //        if (imui.button("test")) {
        //            std.debug.print("tet\n", .{});
        //        }
//
        //        imui.buttonn()
        //            .setLabel("Install All")
        //            .onClick(print)
        //            .size(100, 40)
        //            .build();
        //    });
//
        //    imui.container("content", .{ .child_axis = .vertical, .border_thickness = 2 }, imui.percent(100, 90))({
        //        // list all packages
        //        if (imui.button("test")) {
        //            std.debug.print("tet\n", .{});
        //        }
        //    });
        //});

        ray.drawFPS(0, 0);

        imui.endFrame();
    }
}

fn print() void {
    std.debug.print("Hello World\n", .{});
}
