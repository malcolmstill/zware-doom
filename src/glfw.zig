const std = @import("std");
const mem = std.mem;
const glfw = @import("glfw");
const gl = @import("gl");

// FIXME: add mouse support
// FIXME: use glfw enum numbers instead of scancode
const Event = struct {
    type: enum(u32) {
        keydown,
        keyup,
    },
    scancode: i32,
};

// 128 events is enough for anyone
const Queue = std.fifo.LinearFifo(Event, std.fifo.LinearFifoBufferType{ .Static = 128 });
var queue: Queue = undefined;

var window: glfw.Window = undefined;
var VBO: c_uint = undefined;
var VAO: c_uint = undefined;
var EBO: c_uint = undefined;
var texture: c_uint = undefined;
var program: gl.GLuint = undefined;
var palette_loc: gl.GLint = undefined;

pub fn newWindow(width: u32, height: u32) void {
    queue = Queue.init();

    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }

    window = glfw.Window.create(width, height, "zware doom (mach-glfw)", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 1,
    }) orelse @panic("Couldn't create glfw window");

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    gl.load(proc, glGetProcAddress) catch {
        @panic("Failed to load GL");
    };

    {
        // Here's our setup
        // We are going to make a texture that we update with Doom's
        // screen[0] data. We're going to render that texture onto
        // a rectangle, so we set up 4 vertices and indices for drawing
        // the two triangles of the rect.
        //
        // The pixel data from doom are not directly colours but rather
        // indices into a palette. When doom wants to swap palette
        // we'll get a call to `setPalette` where we update our `palette_loc`
        // uniform which is an int array (of 256 colours)

        loadShader();

        const vertices = [_]f32{
            1.0, 1.0, 0.0, 1.0, 0.0, // top right
            1.0, -1.0, 0.0, 1.0, 1.0, // bottom right
            -1.0, -1.0, 0.0, 0.0, 1.0, // bottom left
            -1.0, 1.0, 0.0, 0.0, 0.0, // top left
        };

        const indices = [_]c_uint{
            0, 1, 3, // indices into `vertices` array of top-right triangle
            1, 2, 3, // indices into `vertices` array of bottom-left triangle
        };

        gl.genVertexArrays(1, &VAO);
        gl.genBuffers(1, &VBO);
        gl.genBuffers(1, &EBO);

        gl.bindVertexArray(VAO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);

        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * @sizeOf(c_uint), &indices, gl.STATIC_DRAW);

        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
        gl.enableVertexAttribArray(0);

        const tex_offset: [*c]c_uint = (3 * @sizeOf(f32));
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), tex_offset);
        gl.enableVertexAttribArray(1);

        gl.genTextures(1, &texture);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        // Use nearest neighbour filtering because our texture data (from doom) are NOT
        // colour data. Rather they are indices into a palette so if we linearly interpolate
        // that data we'll end up with totally incorrect palette indices and hence colours.
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        // Initialise empty texture
        var screen: [320 * 200]u8 = [_]u8{0} ** (320 * 200);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RED, 320, 200, 0, gl.RED, gl.UNSIGNED_BYTE, @as([*c]const u8, @ptrCast(&screen[0])));
        gl.generateMipmap(gl.TEXTURE_2D);
    }

    gl.clearColor(0.5, 0.5, 0.5, 0.5);

    glfw.Window.setKeyCallback(window, queueKeyEvent);

    gl.useProgram(program);

    palette_loc = gl.getUniformLocation(program, "palette");

    // Show window
    glfw.pollEvents();
}

pub fn renderFrame(screen: []const u8) void {
    gl.clear(gl.COLOR_BUFFER_BIT);

    // Update our texture data from the Doom's screen[0]
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 320, 200, gl.RED, gl.UNSIGNED_BYTE, &screen[0]);
    // Draw doom!
    gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

    window.swapBuffers();
    glfw.pollEvents();
}

pub fn pendingEvents() bool {
    glfw.pollEvents();

    return queue.readableLength() > 0;
}

// pendingEvents is expected to be called before nextEvent and so
// we should always have an event available
pub fn nextEvent() Event {
    return queue.readItem() orelse @panic("Expected event");
}

// Update palette uniform (for our fragment shader) from doom's
// palette data
pub fn setPalette(palette: []const u8) void {
    gl.uniform1iv(palette_loc, 256, @alignCast(@ptrCast(&palette[0])));
}

// FIXME: use glfw key numbering
fn queueKeyEvent(win: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    _ = win;
    _ = mods;
    _ = key;

    if (action == .press) {
        queue.writeItem(.{ .scancode = scancode, .type = .keydown }) catch {
            std.debug.print("dropped key event\n", .{});
        };
    }

    if (action == .release) {
        queue.writeItem(.{ .scancode = scancode, .type = .keyup }) catch {
            std.debug.print("dropped key event\n", .{});
        };
    }
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

fn loadShader() void {
    const vertex_source = @embedFile("vertex.glsl");
    const vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex_shader, 1, @as([*c]const [*c]const u8, @ptrCast(&vertex_source)), 0);
    gl.compileShader(vertex_shader);

    var success: c_int = undefined;
    var info_log: [512]u8 = [_]u8{0} ** 512;

    gl.getShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);

    if (success == gl.FALSE) {
        gl.getShaderInfoLog(vertex_shader, 512, 0, &info_log);
        std.log.err("{s}", .{info_log});
        @panic("Vertex shader failed to compile");
    }

    // Create and compile the fragment shader
    const fragment_source = @embedFile("fragment.glsl");
    const fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragment_shader, 1, @as([*c]const [*c]const u8, @ptrCast(&fragment_source)), 0);
    gl.compileShader(fragment_shader);

    gl.getShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);

    if (success == gl.FALSE) {
        gl.getShaderInfoLog(fragment_shader, 512, 0, &info_log);
        std.log.err("{s}", .{info_log});
        @panic("Fragment shader failed to compile");
    }

    // Link the vertex and fragment shader into a shader program
    program = gl.createProgram();
    gl.attachShader(program, vertex_shader);
    gl.attachShader(program, fragment_shader);
    gl.linkProgram(program);

    gl.getProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        gl.getProgramInfoLog(program, 512, 0, &info_log);
        std.log.err("{s}", .{info_log});
        @panic("Program failed to link");
    }
}
