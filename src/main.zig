const std = @import("std");
const ray = @import("raylib");

const imui = @import("imui");

pub fn main() !void {
    // raylib
    try imui.openWindow(1280, 720, "Window");
    defer imui.closeWindow();

    const font = try imui.loadFont("C:\\Windows\\Fonts\\Arial.ttf");
    defer ray.unloadFont(font);
    imui.setFont(font);

    var is_window_open = true;

    const texture = try ray.loadTexture("C:/Users/USER/Desktop/yahoo-cant-login.PNG");
    defer ray.unloadTexture(texture);

    var active_tab: u8 = 0;
    var progress_bar_value: f32 = 0.0;
    var selected_dropdown_item: usize = 0;
    var open = false;

    while (!ray.windowShouldClose()) {
        imui.startFrame();

        imui.container("main", .{ .child_axis = .verticalStack }, .{ .x = 1280, .y = 720 })({
            imui.container("search-tab", .{ .child_axis = .verticalStack }, .{ .x = 1280, .y = 100 })({
                if (imui.button("Search")) {
                    std.debug.print("Hello World\n", .{});
                }
            });

            imui.container("content", .{ .child_axis = .horizontalStack }, .{ .x = 1280, .y = 620 })({
                imui.container("sidebar", .{ .child_axis = .verticalStack }, .{ .x = 300, .y = 620 })({
                    if (imui.button("Network and Wireless")) active_tab = 0;
                    if (imui.button("Bluetooth")) active_tab = 1;
                    if (imui.button("Desktop")) active_tab = 2;
                });

                imui.container("primary", .{ .child_axis = .verticalStack }, .{ .x = 1280 - 300, .y = 620 })({
                    switch (active_tab) {
                        0 => {
                            imui.h1("Network and Wireless");
                            imui.progressBar(&progress_bar_value, 0, 1, "Volume", null, .{ .x = 300, .y = 10 });

                            imui.dropdown(&[_][]const u8{ "Hello", "Foo", "Bar" }, &selected_dropdown_item, &open);
                        },
                        1 => {},
                        2 => {
                            imui.h1("Desktop");
                            if (imui.button("Wallpaper")) {}
                            if (imui.button("Apppearance")) {}
                            if (imui.button("Panel")) {}
                        },
                        else => {},
                    }
                });
            });
        });

        if (is_window_open) {
            imui.subWindow("window 1", &is_window_open)({
                if (imui.button("Hello World 33")) {
                    std.debug.print("Hello World\n", .{});
                }
                if (imui.button("Hello World233")) {
                    std.debug.print("Hello World\n", .{});
                }

                imui.image(texture);
                imui.image(texture);
                imui.image(texture);
            });
        }

        imui.endFrame();
    }
}
