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

    var is_window_open = false;

    const image1 = try imui.loadImage("C:/Users/USER/Desktop/yahoo-cant-login.PNG");

    var active_tab: u8 = 0;
    var progress_bar_value: f32 = 0.0;
    var selected_dropdown_item: usize = 0;
    var open = false;

    var selected_tab: usize = 0;

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

                imui.container("tabs-primary", .{ .child_axis = .verticalStack }, .{ .x = 980, .y = 600 })({
                    imui.container("tabs", .{ .child_axis = .horizontalStack, .border_thickness = 0, .padding = 0 }, .{ .x = 980, .y = 30 })({
                        imui.horizontalTabs(&[_][]const u8{ "Hello", "Foo", "Bar" }, &selected_tab);
                    });

                    imui.container("primary", .{ .child_axis = .verticalStack, .border_thickness = 0 }, .{ .x = 1280 - 320, .y = 570 })({
                        switch (active_tab) {
                            0 => {
                                imui.h1("Network and Wireless");
                                imui.progressBar(&progress_bar_value, 0, 20, 5, "Volume", null, .{ .x = 300, .y = 15 });

                                imui.dropdown(&[_][]const u8{ "Hello", "Foo", "Bar" }, &selected_dropdown_item, &open);

                                imui.image(image1);
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
        });

        if (is_window_open) {
            imui.subWindow("window 1", &is_window_open)({
                if (imui.button("Hello World 33")) {
                    std.debug.print("Hello World\n", .{});
                }
                if (imui.button("Hello World233")) {
                    std.debug.print("Hello World\n", .{});
                }

                imui.image(image1);
                imui.image(image1);
                imui.image(image1);
            });
        }

        imui.endFrame();
    }
}
