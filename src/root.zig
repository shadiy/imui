const std = @import("std");
const testing = std.testing;

const ray = @import("raylib");
const gui = @import("raygui");

var debug_allocator = std.heap.DebugAllocator(.{}).init;
const allocator = debug_allocator.allocator();

const ContainerType = enum {
    none,
    verticalStack,
    horizontalStack,
};

const Style = struct {
    font_size: f32 = 16,
    h1_size: f32 = 32,

    primary: ray.Color = ray.Color.purple,
    secondary: ray.Color = ray.Color.orange,
    tertiary: ray.Color = ray.Color.light_gray,

    background_color: ray.Color = ray.Color.black,
    text_color: ray.Color = ray.Color.ray_white,

    border_thickness: f32 = 4,
    border_color: ray.Color = ray.Color.dark_gray,

    hover_background_color: ray.Color = ray.Color.dark_gray,

    pressed_background_color: ray.Color = ray.Color.red,

    switch_off_color: ray.Color = ray.Color.dark_gray,
    switch_on_color: ray.Color = ray.Color.ray_white,
    switch_handle_color: ray.Color = ray.Color.dark_gray,
};

var style = Style{};

var font: ray.Font = undefined;

const Cursor = struct {
    const Self = @This();

    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: *Self, delta_x: f32, delta_y: f32) void {
        if (curr_container_data) |data| {
            if (data.con_style.child_axis == .horizontalStack) {
                self.x += delta_x;
                self.x += data.con_style.gap;
            } else {
                self.y += delta_y;
                self.y += data.con_style.gap;
            }
        }
    }
};
var global_container_cursor: Cursor = .{};

pub var window_width: f32 = 1280;
pub var window_height: f32 = 720;

pub fn openWindow(width: f32, height: f32, title: []const u8) !void {
    window_width = width;
    window_height = height;

    ray.setConfigFlags(.{ .msaa_4x_hint = true, .window_highdpi = true });

    const titleZ = try formatZ("{s}", .{title});
    ray.initWindow(@intFromFloat(width), @intFromFloat(height), titleZ);

    style = try loadStyle("style.json");

    gui.guiSetStyle(.default, gui.GuiDefaultProperty.background_color, ray.Color.toInt(style.background_color));
    gui.guiSetStyle(.default, gui.GuiControlProperty.border_width, 0);

    ray.setTargetFPS(60);
    //ray.enableEventWaiting();
}

pub fn closeWindow() void {
    window_data_map.deinit();
    container_data_map.deinit();

    images.deinit();

    ray.closeWindow();
}

pub fn startFrame() void {
    ray.beginDrawing();
    ray.clearBackground(style.background_color);

    global_container_cursor.x = 0;
    global_container_cursor.y = 0;
}

pub fn endFrame() void {
    drawDropdownOptions(dropdown_data);

    ray.endDrawing();
}

/// This is a helper function to format strings to a Z string.
/// Uses static buffer length: 4096.
/// If your string is longer than 4096, you will need to use std.fmt.bufPrintZ or std.fmt.allocPrintZ.
fn formatZ(comptime format: []const u8, args: anytype) ![:0]const u8 {
    const S = struct {
        var buf: [4096]u8 = undefined;
    };

    return std.fmt.bufPrintZ(&S.buf, format, args) catch unreachable;
}

/// returns the percent of size of parent container
pub fn percent(x: f32, y: f32) ray.Vector2 {
    const parent_size: ray.Vector2 = if (curr_container_data) |data| .{ .x = data.rect.width, .y = data.rect.height } else .{ .x = window_width, .y = window_height };
    return .{ .x = parent_size.x * (x / 100), .y = parent_size.y * (y / 100) };
}

var images = std.ArrayList(ray.Texture2D).init(allocator);
pub fn loadImage(path: []const u8) !*ray.Texture2D {
    const pathZ = try formatZ("{s}", .{path});
    const tex = try ray.loadTexture(pathZ);
    try images.append(tex);
    return &images.items[images.items.len - 1];
}

pub fn loadFont(path: []const u8) !ray.Font {
    const pathZ = try formatZ("{s}", .{path});
    return try ray.loadFont(pathZ);
}

pub fn setFont(new_font: ray.Font) void {
    font = new_font;
}

fn isMouseOver(rect: ray.Rectangle) bool {
    const mousePos = ray.getMousePosition();
    return mousePos.x >= rect.x and mousePos.x <= rect.x + rect.width and mousePos.y >= rect.y and mousePos.y <= rect.y + rect.height;
}

pub fn loadStyle(path: []const u8) !Style {
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false });
    defer file.close();

    const content = try file.reader().readAllAlloc(allocator, 2024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(Style, allocator, content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    return parsed.value;
}

fn calcPosition() ray.Vector2 {
    var scroll = ray.Vector2{ .x = 0, .y = 0 };
    var window_pos = ray.Vector2{ .x = 0, .y = 0 };

    // cursor is global position
    var cursor = Cursor{};

    if (curr_window_data) |data| {
        scroll = data.container_data.scroll;
        window_pos = .{ .x = data.container_data.rect.x, .y = data.container_data.rect.y };
    } else if (curr_container_data) |data| {
        scroll = data.scroll;
        cursor = data.cursor;
    }

    return .{ .x = cursor.x + window_pos.x + scroll.x, .y = cursor.y + window_pos.y + scroll.y };
}

const ContainerStyle = struct {
    child_axis: ContainerType = .horizontalStack,
    gap: f32 = 6,
    padding: f32 = 20,
    child_width: f32 = 100,
    child_height: f32 = 100,
    rounded_corners: bool = false,
    border_thickness: f32 = 0,
};

const ContainerData = struct {
    scroll: ray.Vector2 = .{ .x = 0, .y = 0 },
    view: ray.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    rect: ray.Rectangle = .{ .x = 0, .y = 0, .width = 500, .height = 500 },
    last_cursor: Cursor = .{},
    cursor: Cursor = .{},
    con_style: ContainerStyle = .{},
};
var container_data_map = std.StringHashMap(ContainerData).init(allocator);
var curr_container_data: ?*ContainerData = null;
var parent_container_data: ?*ContainerData = null;

pub inline fn openContainer(unique_id: []const u8, container_style: ContainerStyle, size: ray.Vector2) void {
    parent_container_data = curr_container_data;

    const pos: ray.Vector2 = .{ .x = global_container_cursor.x, .y = global_container_cursor.y };

    const res = container_data_map.getOrPut(unique_id) catch unreachable;

    var data = res.value_ptr;

    if (!res.found_existing) {
        data.* = .{};
    }

    if (parent_container_data) |parent| {
        if (parent.con_style.child_axis == .horizontalStack) {
            global_container_cursor.x += data.rect.width + parent.con_style.gap;
        } else {
            global_container_cursor.y += data.rect.height + parent.con_style.gap;
        }
    }

    curr_container_data = data;

    data.cursor.x = pos.x + container_style.padding;
    data.cursor.y = pos.y + container_style.padding;
    data.rect = .{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y };
    data.con_style = container_style;

    // scroll
    const content_rect = ray.Rectangle{ .x = 0, .y = 0, .width = data.last_cursor.x, .height = data.last_cursor.y };
    _ = gui.guiScrollPanel(data.rect, null, content_rect, &data.scroll, &data.view);

    if (container_style.border_thickness > 0) {
        if (container_style.rounded_corners) {
            ray.drawRectangleRoundedLinesEx(data.rect, 0.05, 6, container_style.border_thickness, style.border_color);
        } else {
            ray.drawRectangleLinesEx(data.rect, container_style.border_thickness, style.border_color);
        }
    }

    ray.beginScissorMode(@intFromFloat(data.rect.x + container_style.border_thickness), @intFromFloat(data.rect.y + container_style.border_thickness), @intFromFloat(data.rect.width - container_style.border_thickness * 2), @intFromFloat(data.rect.height - container_style.border_thickness * 2));
}

pub fn endContainer(_: void) void {
    if (curr_window_data) |data| data.container_data.last_cursor = .{ .x = global_container_cursor.x, .y = global_container_cursor.y };

    if (curr_container_data) |data| {
        data.last_cursor = data.cursor;
    }

    ray.endScissorMode();
    curr_window_data = null;
    curr_container_data = null;
}

pub inline fn container(unique_id: []const u8, container_style: ContainerStyle, size: ray.Vector2) fn (void) void {
    openContainer(unique_id, container_style, size);
    return endContainer;
}

//pub fn scrollpanel(bounds: ray.Rectangle, content: ray.Rectangle, scroll: *ray.Vector2, view: *ray.Rectangle) void {
//    const RAYGUI_MIN_SCROLLBAR_WIDTH = 40;
//    const RAYGUI_MIN_SCROLLBAR_HEIGHT = 40;
//    const RAYGUI_MIN_MOUSE_WHEEL_SPEED = 20;
//
//    var temp: ray.Rectangle = .{};
//    if (view == null) view = &temp;
//
//    var scrollPos: ray.Vector2 = .{ .x = 0.0, .y = 0.0 };
//    if (scroll != null) scrollPos = *scroll;
//
//    var hasHorizontalScrollBar: bool = (content.width > bounds.width);
//    var hasVerticalScrollBar: bool = (content.height > bounds.height);
//
//    // Recheck to account for the other scrollbar being visible
//    if (!hasHorizontalScrollBar) hasHorizontalScrollBar = (hasVerticalScrollBar and (content.width > (bounds.width - 40)));
//    if (!hasVerticalScrollBar) hasVerticalScrollBar = (hasHorizontalScrollBar and (content.height > (bounds.height - 40)));
//
//    var horizontalScrollBarWidth: i32 = if (hasHorizontalScrollBar) 10 else 0;
//    var verticalScrollBarWidth: i32 = if (hasVerticalScrollBar) 10 else 0;
//    var horizontalScrollBar: ray.Rectangle =
//      .{ .x = bounds.x, .y = bounds.y + bounds.height - horizontalScrollBarWidth, .width = bounds.width - verticalScrollBarWidth, .height = horizontalScrollBarWidth };
//    var verticalScrollBar: ray.Rectangle =
//      .{ .x = bounds.x + bounds.width - verticalScrollBarWidth, .y = bounds.y, .width = verticalScrollBarWidth, .height = bounds.height - horizontalScrollBarWidth };
//
//    // Make sure scroll bars have a minimum width/height
//    if (horizontalScrollBar.width < RAYGUI_MIN_SCROLLBAR_WIDTH) horizontalScrollBar.width = RAYGUI_MIN_SCROLLBAR_WIDTH;
//    if (verticalScrollBar.height < RAYGUI_MIN_SCROLLBAR_HEIGHT) verticalScrollBar.height = RAYGUI_MIN_SCROLLBAR_HEIGHT;
//
//    // Calculate view area (area without the scrollbars)
//    view.* = .{ .x = bounds.x, .y = bounds.y, .width = bounds.width - verticalScrollBarWidth, .height = bounds.height - horizontalScrollBarWidth };
//
//    // Clip view area to the actual content size
//    if (view.width > content.width) view.width = content.width;
//    if (view.height > content.height) view.height = content.height;
//
//    var horizontalMin: f32 = if (hasHorizontalScrollBar) 0.0 else -1.0;
//    var horizontalMax: f32 = if (hasHorizontalScrollBar) content.width - bounds.width + verticalScrollBarWidth else 0;
//    var verticalMin: f32 = if (hasVerticalScrollBar) 0.0 else -1.0;
//    var verticalMax: f32 = if (hasVerticalScrollBar) content.height - bounds.height + horizontalScrollBarWidth else 0;
//
//    // Update control
//    //--------------------------------------------------------------------
//    const mousePoint: ray.Vector2 = ray.getMousePosition();
//
//    // Check button state
//    if (ray.checkCollisionPointRec(mousePoint, bounds)) {
//        //#if defined(SUPPORT_SCROLLBAR_KEY_INPUT)
//        //            if (hasHorizontalScrollBar)
//        //            {
//        //                if (IsKeyDown(KEY_RIGHT)) scrollPos.x -= GuiGetStyle(SCROLLBAR, SCROLL_SPEED);
//        //                if (IsKeyDown(KEY_LEFT)) scrollPos.x += GuiGetStyle(SCROLLBAR, SCROLL_SPEED);
//        //            }
//        //
//        //            if (hasVerticalScrollBar)
//        //            {
//        //                if (IsKeyDown(KEY_DOWN)) scrollPos.y -= GuiGetStyle(SCROLLBAR, SCROLL_SPEED);
//        //                if (IsKeyDown(KEY_UP)) scrollPos.y += GuiGetStyle(SCROLLBAR, SCROLL_SPEED);
//        //            }
//        //#endif
//        const wheelMove: f32 = ray.getMouseWheelMove();
//
//        // Set scrolling speed with mouse wheel based on ratio between bounds and content
//        const mouseWheelSpeed: ray.Vector2 = .{ .x = content.width / bounds.width, .y = content.height / bounds.height };
//        //if (mouseWheelSpeed.x < RAYGUI_MIN_MOUSE_WHEEL_SPEED) mouseWheelSpeed.x = RAYGUI_MIN_MOUSE_WHEEL_SPEED;
//        //if (mouseWheelSpeed.y < RAYGUI_MIN_MOUSE_WHEEL_SPEED) mouseWheelSpeed.y = RAYGUI_MIN_MOUSE_WHEEL_SPEED;
//
//        // Horizontal and vertical scrolling with mouse wheel
//        if (hasHorizontalScrollBar and (ray.isKeyDown(.left_control) or ray.isKeyDown(.left_shift))) {
//              scrollPos.x += wheelMove * mouseWheelSpeed.x else scrollPos.y += wheelMove * mouseWheelSpeed.y; // Vertical scroll
//        //}
//
//    }
//
//    // Normalize scroll values
//    if (scrollPos.x > -horizontalMin) scrollPos.x = -horizontalMin;
//    if (scrollPos.x < -horizontalMax) scrollPos.x = -horizontalMax;
//    if (scrollPos.y > -verticalMin) scrollPos.y = -verticalMin;
//    if (scrollPos.y < -verticalMax) scrollPos.y = -verticalMax;
//    //--------------------------------------------------------------------
//
//    // Draw control
//    //--------------------------------------------------------------------
//
//    ray.drawRectangleRec(bounds, style.background_color); // Draw background
//
//    // Save size of the scrollbar slider
//    const S = struct {
//        var scroll_slider_size: f32 = 1;
//    };
//
//    // Draw horizontal scrollbar if visible
//    if (hasHorizontalScrollBar) {
//        // Change scrollbar slider size to show the diff in size between the content width and the widget width
//        S.scroll_slider_size = ((bounds.width - verticalScrollBarWidth) / content.width) * (bounds.width - verticalScrollBarWidth);
//        scrollPos.x = -GuiScrollBar(horizontalScrollBar, -scrollPos.x, horizontalMin, horizontalMax);
//    } else scrollPos.x = 0.0f;
//
//    // Draw vertical scrollbar if visible
//    if (hasVerticalScrollBar) {
//        // Change scrollbar slider size to show the diff in size between the content height and the widget height
//        S.scroll_slider_size = ((bounds.height - horizontalScrollBarWidth) / content.height) * (bounds.height - horizontalScrollBarWidth);
//        scrollPos.y = -GuiScrollBar(verticalScrollBar, -scrollPos.y, verticalMin, verticalMax);
//    } else scrollPos.y = 0.0f;
//
//    // Draw scrollbar lines depending on current state
//    ray.drawRectangleRec(bounds, GuiGetStyle(LISTVIEW, BORDER_WIDTH), GetColor(GuiGetStyle(LISTVIEW, BORDER + (state * 3))), BLANK);
//
//    if (scroll != null) scroll.* = scrollPos;
//
//    return result;
//}

pub fn button(str: []const u8) bool {
    const pos = calcPosition();
    const res = button2(str, pos, .{ .x = 180, .y = 40 });
    if (curr_container_data) |data| data.cursor.add(180, 40);
    return res;
}

pub fn miniButton(str: []const u8) bool {
    const pos = calcPosition();
    const res = button2(str, pos, .{ .x = 10, .y = 10 });
    if (curr_container_data) |data| data.cursor.add(10, 10);
    return res;
}

fn button2(str: []const u8, position: ray.Vector2, size: ray.Vector2) bool {
    return button3(str, position, size, style.primary, style.secondary, style.pressed_background_color);
}

pub fn button3(str: []const u8, position: ray.Vector2, size: ray.Vector2, normal: ray.Color, hover: ray.Color, pressed: ray.Color) bool {
    const rect: ray.Rectangle = .{ .x = position.x, .y = position.y, .width = size.x, .height = size.y };

    var res = false;

    if (isMouseOver(rect)) {
        ray.drawRectangleRec(rect, hover);

        if (ray.isMouseButtonDown(.left)) {
            ray.drawRectangleRec(rect, pressed);
        }

        if (ray.isMouseButtonReleased(.left)) {
            res = true;
        }
    } else {
        ray.drawRectangleRec(rect, normal);
        ray.drawRectangleLinesEx(rect, style.border_thickness, style.border_color);
    }

    const textZ = formatZ("{s}", .{str}) catch unreachable;

    const text_size = ray.measureTextEx(font, textZ, style.font_size, 1);

    ray.drawTextEx(font, textZ, .{ .x = rect.x + rect.width / 2 - text_size.x / 2, .y = rect.y + rect.height / 2 - text_size.y / 2 }, style.font_size, 1, style.text_color);

    return res;
}

pub fn text(str: []const u8) void {
    const strZ = formatZ("{s}", .{str}) catch unreachable;
    const pos = calcPosition();
    ray.drawTextEx(font, strZ, pos, style.font_size, 1, style.text_color);
    const text_size = ray.measureTextEx(font, strZ, style.font_size, 1);

    if (curr_container_data) |data| data.cursor.add(text_size.x, text_size.y);
}

pub fn text2(str: [:0]const u8, pos: ray.Vector2) void {
    ray.drawTextEx(font, str, pos, style.font_size, 1, style.text_color);
}

pub fn h1(str: []const u8) void {
    const strZ = formatZ("{s}", .{str}) catch unreachable;
    const pos = calcPosition();
    ray.drawTextEx(font, strZ, pos, style.font_size * 2, 1, style.text_color);
    const text_size = ray.measureTextEx(font, strZ, style.font_size * 2, 1);

    if (curr_container_data) |data| data.cursor.add(text_size.x, text_size.y);
}

const WindowData = struct {
    dragging: bool = false,
    container_data: ContainerData = .{},
};

var window_data_map = std.StringHashMap(WindowData).init(allocator);
var curr_window_data: ?*WindowData = null;

pub inline fn subWindow(unique_id: []const u8, open: *bool) fn (void) void {
    const title_bar_height: f32 = 30;

    global_container_cursor.x = 0;
    global_container_cursor.y = 30;

    const res = window_data_map.getOrPut(unique_id) catch unreachable;

    var data = res.value_ptr;

    if (!res.found_existing) {
        data.* = .{};
    }

    curr_window_data = data;

    if (data.dragging) {
        const pos = ray.getMouseDelta();

        data.container_data.rect.x += pos.x;
        data.container_data.rect.y += pos.y;
    }

    var title_bar_rect = data.container_data.rect;
    title_bar_rect.height = title_bar_height;
    ray.drawRectangleRec(title_bar_rect, ray.Color.black);

    // title bar
    if (ray.isMouseButtonDown(.left) and isMouseOver(title_bar_rect)) {
        data.dragging = true;
    }

    if (ray.isMouseButtonReleased(.left) and data.dragging) {
        data.dragging = false;
    }

    // close button
    const x_button_pos: ray.Vector2 = .{ .x = data.container_data.rect.x + data.container_data.rect.width - 10, .y = data.container_data.rect.y + 5 };
    open.* = !button2("X", x_button_pos, .{ .x = 10, .y = 10 });

    // scroll
    var bounds = data.container_data.rect;
    bounds.y += title_bar_height;
    bounds.height -= title_bar_height;
    _ = gui.guiScrollPanel(bounds, null, .{ .x = 0, .y = 0, .width = 280, .height = data.container_data.last_cursor.y * 10 }, &data.container_data.scroll, &data.container_data.view);

    ray.beginScissorMode(@intFromFloat(bounds.x), @intFromFloat(bounds.y), @intFromFloat(bounds.width), @intFromFloat(bounds.height));

    return endContainer;
}

pub fn image(texture: *ray.Texture2D) void {
    const pos = calcPosition();

    const position: ray.Vector2 = .{ .x = pos.x, .y = pos.y };
    texture.drawEx(position, 0, 1, ray.Color.white);
    if (curr_container_data) |data| data.cursor.add(@floatFromInt(texture.width), @floatFromInt(texture.height));
}

pub fn slider(value: *f32, min: f32, max: f32, step: f32, text_left: ?[]const u8, text_right: ?[]const u8, size: ray.Vector2) void {
    var value_normalized = (value.* - min) / (max - min);
    const step_normaized = step / (max - min);

    const pos = calcPosition();

    const value_text_left = text_left orelse "";
    const value_text_right = text_right orelse "";

    const value_text_left_z = formatZ("{s}", .{value_text_left}) catch unreachable;
    const value_text_left_size = ray.measureTextEx(font, value_text_left_z, style.font_size, 1);

    const value_text_right_z = formatZ("{s}", .{value_text_right}) catch unreachable;
    const value_text_right_size = ray.measureTextEx(font, value_text_right_z, style.font_size, 1);

    const value_text_left_pos = ray.Vector2{ .x = pos.x, .y = pos.y + size.y / 2 - value_text_left_size.y / 2 };
    const value_text_right_pos = ray.Vector2{ .x = pos.x + size.x - value_text_right_size.x, .y = pos.y + size.y / 2 - value_text_right_size.y / 2 };

    const background_rect: ray.Rectangle = .{ .x = pos.x + value_text_left_size.x + 2, .y = pos.y, .width = size.x - value_text_right_size.x - value_text_left_size.x - 4, .height = size.y };
    var fill_rect = background_rect;
    fill_rect.width *= value_normalized;

    text2(value_text_left_z, value_text_left_pos);
    text2(value_text_right_z, value_text_right_pos);

    ray.drawRectangleRec(background_rect, style.tertiary);
    ray.drawRectangleRec(fill_rect, style.switch_on_color);
    if (curr_container_data) |data| data.cursor.add(background_rect.width + value_text_left_size.x + value_text_right_size.x, background_rect.height);

    if (isMouseOver(background_rect)) {
        ray.drawCircleV(.{ .x = background_rect.x + background_rect.width * value_normalized, .y = background_rect.y + background_rect.height / 2 }, 10, style.text_color);

        if (ray.isMouseButtonDown(.left)) {
            const mouse_pos = ray.getMousePosition();
            value_normalized = (mouse_pos.x - background_rect.x) / background_rect.width;
        }
    }

    const step_mod = @mod(value_normalized, step_normaized);
    if (step_mod >= step_normaized / 2) {
        value_normalized += step_normaized - step_mod;
    } else if (step_mod < step_normaized / 2) {
        value_normalized -= step_mod;
    }

    value.* = value_normalized * (max - min) + min;
    value.* = std.math.clamp(value.*, min, max);
}

const DropdownData = struct {
    rect: ray.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    selected: *usize = undefined,
    options: []const []const u8 = undefined,
};
var dropdown_data: ?DropdownData = null;

fn drawDropdownOptions(maybe_data: ?DropdownData) void {
    if (maybe_data == null) return;

    const data = &maybe_data.?;
    const rect = data.rect;

    for (data.options, 0..) |option, i| {
        const i_f32: f32 = @floatFromInt(i);
        if (button2(option, .{ .x = rect.x, .y = rect.y + rect.height * i_f32 + rect.height }, .{ .x = rect.width, .y = rect.height })) {
            data.selected.* = i;
            dropdown_data = null;
        }
    }
}

// TODO: draw the dropdown menu on top of everything else
pub fn dropdown(options: []const []const u8, selected: *usize) void {
    const pos = calcPosition();
    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 180, .height = 40 };

    if (button(options[selected.*])) {
        if (dropdown_data == null) {
            dropdown_data = .{
                .rect = rect,
                .selected = selected,
                .options = options,
            };
        } else {
            dropdown_data = null;
        }
    }

    gui.guiDrawIcon(3, @intFromFloat(rect.x + rect.width - 30), @intFromFloat(rect.y + rect.height / 4), 1, style.text_color);
}

pub fn horizontalTabs(tabs: []const []const u8, selected: *usize) void {
    const pos = calcPosition();

    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 100, .height = 20 };

    var prev_tabs_width_sum: f32 = 0;

    for (tabs, 0..) |tab, i| {
        const tabZ = formatZ("{s}", .{tab}) catch unreachable;
        const text_size = ray.measureTextEx(font, tabZ, style.font_size, 1);

        const tab_rect: ray.Rectangle = .{ .x = pos.x + prev_tabs_width_sum, .y = pos.y, .width = text_size.x + 20, .height = text_size.y + 10 };

        prev_tabs_width_sum += tab_rect.width;

        const normal_color = if (i == selected.*) style.primary else style.secondary;

        if (button3(tab, .{ .x = tab_rect.x, .y = tab_rect.y }, .{ .x = tab_rect.width, .y = tab_rect.height }, normal_color, style.secondary, style.pressed_background_color)) {
            selected.* = i;
        }
    }

    if (curr_container_data) |data| data.cursor.add(prev_tabs_width_sum, rect.height);
    if (curr_window_data) |data| data.container_data.cursor.add(prev_tabs_width_sum, rect.height);
}

pub fn verticalTabs(tabs: []const []const u8, selected: *usize, tab_size: ray.Vector2) void {
    const pos = calcPosition();

    var prev_tabs_height_sum: f32 = 0;

    for (tabs, 0..) |tab, i| {
        const tab_rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y + prev_tabs_height_sum, .width = tab_size.x, .height = tab_size.y };

        prev_tabs_height_sum += tab_rect.height;

        const normal_color = if (i == selected.*) style.primary else style.secondary;

        if (button3(tab, .{ .x = tab_rect.x, .y = tab_rect.y }, tab_size, normal_color, style.secondary, style.pressed_background_color)) {
            selected.* = i;
        }
    }

    if (curr_container_data) |data| data.cursor.add(tab_size.x, prev_tabs_height_sum);
    if (curr_window_data) |data| data.container_data.cursor.add(tab_size.x, prev_tabs_height_sum);
}

pub fn toggleSwitch(value: *bool) void {
    const pos = calcPosition();
    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 40, .height = 20 };

    const backgorund_rect: ray.Rectangle = .{ .x = rect.x, .y = rect.y, .width = rect.width, .height = rect.height };
    const background_color = if (value.*) style.switch_on_color else style.switch_off_color;
    ray.drawRectangleRounded(backgorund_rect, 1, 8, background_color);

    const radius = backgorund_rect.height / 2;
    const center_x = if (value.*) backgorund_rect.x + backgorund_rect.width / 2 + radius else backgorund_rect.x + radius;
    const center_y = backgorund_rect.y + backgorund_rect.height / 2;
    ray.drawCircleV(.{ .x = center_x, .y = center_y }, radius, style.switch_handle_color);

    if (isMouseOver(backgorund_rect) and ray.isMouseButtonPressed(.left)) {
        value.* = !value.*;
    }

    if (curr_container_data) |data| data.cursor.add(rect.width, rect.height);
    if (curr_window_data) |data| data.container_data.cursor.add(rect.width, rect.height);
}

pub fn checkbox(value: *bool) void {
    const pos = calcPosition();

    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 20, .height = 20 };

    if (isMouseOver(rect) and ray.isMouseButtonPressed(.left)) {
        value.* = !value.*;
    }

    const color = if (value.*) style.switch_on_color else style.switch_off_color;
    ray.drawRectangleRec(rect, color);

    if (curr_container_data) |data| data.cursor.add(rect.width, rect.height);
    if (curr_window_data) |data| data.container_data.cursor.add(rect.width, rect.height);
}

pub fn divider() void {
    const pos = calcPosition();

    const size_x = if (curr_container_data) |data| data.rect.width else 0;
    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = size_x, .height = 1 };

    ray.drawLineEx(.{ .x = rect.x, .y = rect.y }, .{ .x = rect.x + size_x, .y = rect.y }, rect.height, style.text_color);

    if (curr_container_data) |data| data.cursor.add(rect.width, rect.height);
    if (curr_window_data) |data| data.container_data.cursor.add(rect.width, rect.height);
}

pub fn radioButtons(options: []const []const u8, selected: *usize) void {
    const pos = calcPosition();

    const radius: f32 = 10;

    var max_width: f32 = 0;

    for (options, 0..) |option, i| {
        const i_f32: f32 = @floatFromInt(i);
        const center: ray.Vector2 = .{ .x = pos.x + radius, .y = pos.y + i_f32 * (radius * 2 + 4) + radius };

        const formated = formatZ("{s}", .{option}) catch unreachable;

        text2(formated, .{ .x = center.x + radius + 4, .y = center.y - radius / 5 });

        const color = if (i == selected.*) style.switch_on_color else style.switch_off_color;
        ray.drawCircleV(center, radius, color);

        const rect: ray.Rectangle = .{ .x = center.x - radius, .y = center.y - radius, .width = radius * 2, .height = radius * 2 };

        if (isMouseOver(rect) and ray.isMouseButtonPressed(.left)) {
            selected.* = i;
        }

        const text_width: f32 = @floatFromInt(ray.measureText(formated, @intFromFloat(style.font_size)));
        max_width = @max(max_width, text_width);
    }

    const options_len: f32 = @floatFromInt(options.len);

    if (curr_container_data) |data| data.cursor.add(max_width, options_len * radius * 2);
    if (curr_window_data) |data| data.container_data.cursor.add(max_width, options_len * radius * 2);
}

pub fn numberField(value: *f32, min: f32, max: f32, step: f32) void {
    const pos = calcPosition();

    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 100, .height = 20 };
    const element_width = rect.width / 3;

    if (button2("-", pos, .{ .x = element_width, .y = rect.height })) {
        value.* -= step;
        if (value.* < min) value.* = min;
    }

    const formated = formatZ("{d:.0}", .{value.*}) catch unreachable;
    const text_size = ray.measureTextEx(font, formated, style.font_size, 1);
    text2(formated, .{ .x = rect.x + element_width + element_width / 2 - text_size.x / 2, .y = rect.y + text_size.y / 4 });

    if (button2("+", pos.add(.{ .x = element_width * 2, .y = 0 }), .{ .x = element_width, .y = rect.height })) {
        value.* += step;
        if (value.* > max) value.* = max;
    }
}

var input_cursor: usize = 0;

pub fn input(curr_text: *std.ArrayList(u8), active: *bool) void {
    const pos = calcPosition();
    const rect: ray.Rectangle = .{ .x = pos.x, .y = pos.y, .width = 100, .height = 20 };

    ray.drawRectangleLinesEx(rect, 1, style.text_color);

    if (isMouseOver(rect) and ray.isMouseButtonPressed(.left)) {
        active.* = true;
    }

    if (active.*) {
        while (true) {
            const char: u8 = @intCast(ray.getCharPressed());
            if (char == 0) break;

            if (char == 8) {
                _ = curr_text.orderedRemove(input_cursor - 1);
                input_cursor -= 1;
            } else if (char == 13) {
                active.* = false;
                break;
            } else {
                curr_text.insert(input_cursor, char) catch unreachable;
                input_cursor += 1;
            }
        }
    }

    const formated = formatZ("{s}", .{curr_text.items}) catch unreachable;

    const text_measure = ray.measureTextEx(font, formated, style.font_size, 1);

    const text_pos = pos.add(.{ .x = 4, .y = rect.height / 2 - text_measure.y / 2 });

    ray.drawTextEx(font, formated, text_pos, style.font_size, 1, ray.Color.white);

    if (curr_container_data) |data| data.cursor.add(rect.width, rect.height);
    if (curr_window_data) |data| data.container_data.cursor.add(rect.width, rect.height);
}
