const std = @import("std");
const ray = @import("raylib");

const imui = @import("imui");

var debug_allocator = std.heap.DebugAllocator(.{}).init;
const allocator = debug_allocator.allocator();

pub fn main() !void {
    // raylib
    try imui.openWindow(1280, 720, "Window");
    defer imui.closeWindow();

    const font = try imui.loadFont("C:\\Windows\\Fonts\\Arial.ttf");
    defer ray.unloadFont(font);
    imui.setFont(font);

    var is_window_open = false;

    const image1 = try imui.loadImage("C:/Users/USER/Desktop/yahoo-cant-login.PNG");

    var active_tab: usize = 0;
    var progress_bar_value: f32 = 0.0;
    var selected_dropdown_item: usize = 0;

    var onoff: bool = false;
    var check: bool = false;

    var input = std.ArrayList(u8).init(allocator);
    var active = false;

    var selected_radio_button: usize = 0;

    var number_field_value: f32 = 0;

    while (!ray.windowShouldClose()) {
        imui.startFrame();

        imui.container("main", .{ .child_axis = .verticalStack }, imui.percent(100, 100))({
            imui.container("search-tab", .{ .child_axis = .verticalStack }, imui.percent(100, 10))({
                if (imui.button("Search")) {
                    std.debug.print("Hello World\n", .{});
                }
            });

            imui.container("content", .{ .child_axis = .horizontalStack }, imui.percent(100, 90))({
                imui.container("sidebar", .{ .child_axis = .verticalStack }, imui.percent(20, 100))({
                    imui.verticalTabs(&[_][]const u8{ "Network and Wireless", "Bluetooth", "Desktop" }, &active_tab, imui.percent(90, 5));
                });

                imui.container("primary", .{ .child_axis = .verticalStack, .border_thickness = 0 }, imui.percent(70, 100))({
                    switch (active_tab) {
                        0 => {
                            imui.h1("Network and Wireless");
                            imui.slider(&progress_bar_value, 0, 20, 5, "Volume", null, .{ .x = 300, .y = 15 });

                            imui.dropdown(&[_][]const u8{ "Hello", "Foo", "Bar" }, &selected_dropdown_item);

                            imui.radioButtons(&[_][]const u8{ "Hello", "Foo", "Bar" }, &selected_radio_button);
                        },
                        1 => {
                            imui.h1("Bluetooth");
                            imui.toggleSwitch(&onoff);
                            imui.divider();
                            imui.checkbox(&check);
                            imui.input(&input, &active);
                            imui.numberField(&number_field_value, 0, 100, 1);
                        },
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

                imui.image(image1);
                imui.image(image1);
                imui.image(image1);
            });
        }

        imui.endFrame();
    }
}
