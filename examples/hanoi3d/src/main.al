// 3D misty Hanoi tower.
//
// The emitted C program must:
//   - include <GL/freeglut.h>, <GL/glu.h>, <math.h> and <stdio.h>
//   - link with -lGL -lGLU -lglut -lm
//   - build a 64x64 procedural wood texture (grain + dark knots + speckles)
//   - draw every disk, peg and the platform as a HAND-BUILT textured
//     cylinder: a GL_QUADS side wall plus a GL_TRIANGLE_FAN cap, each with
//     its own glTexCoord2f. Do NOT use gluCylinder, gluDisk or
//     glutSolidCylinder: this Mesa build renders GLU shapes without their
//     caps, and freeglut's cylinder carries no texture coordinates.
//   - tint each disk with a different wood tone (GL_MODULATE + glColor3f)
//   - enable GL_FOG with a pale sky colour for depth mist
//   - add drifting translucent mist motes (GL_POINTS, alpha blended)
//   - animate the real Hanoi solution: disks fly between pegs on an arc
//   - rotate the camera with the arrow keys and slowly orbit on its own

extern "C" {
    function printf(fmt: *const u8, ...): i32;
    function sinf(x: f32): f32;
    function cosf(x: f32): f32;

    function glutInit(argc: i32, argv: *const u8): void;
    function glutInitDisplayMode(mode: u32): void;
    function glutInitWindowSize(width: i32, height: i32): void;
    function glutCreateWindow(title: *const u8): i32;
    function glutDisplayFunc(cb: *const u8): void;
    function glutSpecialFunc(cb: *const u8): void;
    function glutReshapeFunc(cb: *const u8): void;
    function glutTimerFunc(ms: i32, cb: *const u8, data: i32): void;
    function glutMainLoop(): void;
    function glutPostRedisplay(): void;
    function glutSwapBuffers(): void;
    function glutGet(mode: i32): i32;

    function glClear(mask: u32): void;
    function glClearColor(r: f32, g: f32, b: f32, a: f32): void;
    function glLoadIdentity(): void;
    function glPushMatrix(): void;
    function glPopMatrix(): void;
    function glTranslatef(x: f32, y: f32, z: f32): void;
    function glRotatef(angle: f32, x: f32, y: f32, z: f32): void;
    function glColor3f(r: f32, g: f32, b: f32): void;
    function glColor4f(r: f32, g: f32, b: f32, a: f32): void;
    function glEnable(cap: u32): void;
    function glDisable(cap: u32): void;
    function glBlendFunc(sf: u32, df: u32): void;
    function glDepthMask(flag: u32): void;
    function glMatrixMode(mode: u32): void;
    function glViewport(x: i32, y: i32, width: i32, height: i32): void;
    function glFogi(pname: u32, param: i32): void;
    function glFogf(pname: u32, param: f32): void;
    function glFogfv(pname: u32, params: *const f32): void;
    function glMaterialfv(face: u32, pname: u32, params: *const f32): void;
    function glLightfv(light: u32, pname: u32, params: *const f32): void;
    function glLightModelfv(pname: u32, params: *const f32): void;
    function glColorMaterial(face: u32, mode: u32): void;
    function glGenTextures(n: i32, ids: *mut u32): void;
    function glBindTexture(target: u32, id: u32): void;
    function glTexImage2D(target: u32, level: i32, internal: i32, w: i32, h: i32, border: i32, fmt: u32, type: u32, pixels: *const u8): void;
    function glTexParameteri(target: u32, pname: u32, param: i32): void;
    function glTexEnvi(target: u32, pname: u32, param: i32): void;
    function glBegin(mode: u32): void;
    function glEnd(): void;
    function glVertex3f(x: f32, y: f32, z: f32): void;
    function glTexCoord2f(s: f32, t: f32): void;
    function glNormal3f(x: f32, y: f32, z: f32): void;
    function glPointSize(size: f32): void;
    function glPerspective(fovy: f64, aspect: f64, zNear: f64, zFar: f64): void;
    function gluLookAt(eyeX: f64, eyeY: f64, eyeZ: f64, centerX: f64, centerY: f64, centerZ: f64, upX: f64, upY: f64, upZ: f64): void;
}

// OpenGL constants, named exactly as in <GL/gl.h>.
let GL_DEPTH_TEST: u32 = 0x0B71;
let GL_LIGHTING: u32 = 0x0B50;
let GL_LIGHT0: u32 = 0x4000;
let GL_COLOR_MATERIAL: u32 = 0x0B57;
let GL_LIGHT_MODEL_AMBIENT: u32 = 0x0B57;
let GL_AMBIENT_AND_DIFFUSE: u32 = 0x1601;
let GL_FRONT: u32 = 0x0404;
let GL_POSITION: u32 = 0x1202;
let GL_FOG: u32 = 0x0B60;
let GL_FOG_MODE: u32 = 0x0B65;
let GL_FOG_START: u32 = 0x0B63;
let GL_FOG_END: u32 = 0x0B64;
let GL_FOG_COLOR: u32 = 0x0B66;
let GL_LINEAR: i32 = 0x2601;
let GL_BLEND: u32 = 0x0BE2;
let GL_SRC_ALPHA: u32 = 0x0302;
let GL_ONE_MINUS_SRC_ALPHA: u32 = 0x0303;
let GL_POINT_SMOOTH: u32 = 0x0B11;
let GL_TEXTURE_2D: u32 = 0x0DE1;
let GL_TEXTURE_ENV: u32 = 0x2300;
let GL_TEXTURE_ENV_MODE: u32 = 0x2200;
let GL_TEXTURE_MIN_FILTER: u32 = 0x2801;
let GL_TEXTURE_MAG_FILTER: u32 = 0x2800;
let GL_TEXTURE_WRAP_S: u32 = 0x2802;
let GL_TEXTURE_WRAP_T: u32 = 0x2803;
let GL_REPEAT: i32 = 0x2901;
let GL_MODULATE: i32 = 0x2100;
let GL_RGB: u32 = 0x1907;
let GL_UNSIGNED_BYTE: u32 = 0x1401;
let GL_PROJECTION: u32 = 0x1701;
let GL_MODELVIEW: u32 = 0x1700;
let GL_QUADS: u32 = 0x0007;
let GL_TRIANGLE_FAN: u32 = 0x0006;
let GL_POINTS: u32 = 0x0000;
let GLUT_ELAPSED_TIME: i32 = 0x02BC;
let GLUT_KEY_LEFT: i32 = 100;
let GLUT_KEY_RIGHT: i32 = 102;
let GLUT_KEY_UP: i32 = 101;
let GLUT_KEY_DOWN: i32 = 103;

let DISKS: i32 = 4;
let TEX_SIZE: i32 = 64;
let SLICES: i32 = 32;
let MOVE_MS: i32 = 800;
let TOTAL_MOVES: i32 = 15;
let PEG_X0: f32 = -1.15;
let PEG_X1: f32 = 0.0;
let PEG_X2: f32 = 1.15;
let PEG_HEIGHT: f32 = 1.05;
let DISK_HEIGHT: f32 = 0.13;
let DISK_GAP: f32 = 0.15;
let PI: f32 = 3.14159265;

var woodTex: u8[12288];
var mvFrom: i32[16];
var mvTo: i32[16];
var mvDisk: i32[16];
var mvCount: i32 = 0;
var keyYaw: f32 = 0.0;
var keyPitch: f32 = 14.0;
var camTarget: vec3 = vec3(0.0, 0.42, 0.0);
var camPos: vec3 = vec3(0.0, 0.0, 0.0);

function texHash(x: u32, y: u32): u32 {
    var h: u32 = x * 374761393;
    h = h + y * 668265263;
    h = h ^ (h >> 13);
    h = h * 1274126177;
    return h ^ (h >> 16);
}

function texRand(x: u32, y: u32): f32 {
    return (texHash(x, y) as f32) / 4294967296.0;
}

// Wood: vertical grain, dark knots, fine speckles.
function buildWoodTexture(): void {
    var px: i32 = 0;
    while px < TEX_SIZE {
        var py: i32 = 0;
        while py < TEX_SIZE {
            let fx: f32 = px as f32;
            let fy: f32 = py as f32;
            let n: f32 = texRand(px as u32, py as u32);
            let knot: f32 = texRand((px / 5) as u32, (py / 5) as u32);
            let grain: f32 = sinf(fx * 0.55 + 3.0 * sinf(fy * 0.09) + 1.2 * (n - 0.5));
            let g: f32 = 0.55 + 0.45 * grain;
            var rr: f32 = 0.38 + 0.52 * g;
            var gg: f32 = 0.21 + 0.37 * g;
            var bb: f32 = 0.09 + 0.21 * g;
            if knot > 0.93 {
                rr = rr * 0.25;
                gg = gg * 0.22;
                bb = bb * 0.18;
            }
            if n > 0.99 {
                rr = rr * 0.40;
                gg = gg * 0.38;
                bb = bb * 0.34;
            }
            let idx: i32 = (py * TEX_SIZE + px) * 3;
            woodTex[idx] = (rr * 255.0) as u8;
            woodTex[idx + 1] = (gg * 255.0) as u8;
            woodTex[idx + 2] = (bb * 255.0) as u8;
            py = py + 1;
        }
        px = px + 1;
    }
}

// A textured cylinder built by hand: quad side wall plus triangle-fan caps.
// The side wall runs along +Z from z=0 to z=height. The caller rotates it.
function drawCylinder(radius: f32, height: f32): void {
    var i: i32 = 0;
    while i < SLICES {
        let a0: f32 = 2.0 * PI * i as f32 / SLICES as f32;
        let a1: f32 = 2.0 * PI * (i + 1) as f32 / SLICES as f32;
        let u0: f32 = i as f32 / SLICES as f32;
        let u1: f32 = (i + 1) as f32 / SLICES as f32;
        let c0: f32 = cosf(a0);
        let s0: f32 = sinf(a0);
        let c1: f32 = cosf(a1);
        let s1: f32 = sinf(a1);

        glBegin(GL_QUADS);
        glNormal3f(c0, s0, 0.0);
        glTexCoord2f(u0, 0.0);
        glVertex3f(c0 * radius, s0 * radius, 0.0);
        glNormal3f(c1, s1, 0.0);
        glTexCoord2f(u1, 0.0);
        glVertex3f(c1 * radius, s1 * radius, 0.0);
        glNormal3f(c1, s1, 0.0);
        glTexCoord2f(u1, 1.0);
        glVertex3f(c1 * radius, s1 * radius, height);
        glNormal3f(c0, s0, 0.0);
        glTexCoord2f(u0, 1.0);
        glVertex3f(c0 * radius, s0 * radius, height);
        glEnd();
        i = i + 1;
    }

    // Top cap, textured radially so the grain reads as wood rings.
    glBegin(GL_TRIANGLE_FAN);
    glNormal3f(0.0, 0.0, 1.0);
    glTexCoord2f(0.5, 0.5);
    glVertex3f(0.0, 0.0, height);
    var j: i32 = 0;
    while j <= SLICES {
        let a: f32 = 2.0 * PI * j as f32 / SLICES as f32;
        let c: f32 = cosf(a);
        let s: f32 = sinf(a);
        glNormal3f(0.0, 0.0, 1.0);
        glTexCoord2f(0.5 + c * 0.5, 0.5 + s * 0.5);
        glVertex3f(c * radius, s * radius, height);
        j = j + 1;
    }
    glEnd();
}

function planMoves(n: i32, base: i32, from: i32, to: i32, aux: i32): void {
    if n == 0 {
        return;
    }
    planMoves(n - 1, base, from, aux, to);
    mvFrom[mvCount] = from;
    mvTo[mvCount] = to;
    mvDisk[mvCount] = base + n - 1;
    mvCount = mvCount + 1;
    planMoves(n - 1, base, aux, to, from);
}

function pegX(peg: i32): f32 {
    if peg == 0 { return PEG_X0; }
    if peg == 1 { return PEG_X1; }
    return PEG_X2;
}

function diskRadius(d: i32): f32 {
    return 0.20 + 0.08 * d as f32;
}

// One wood tone per disk: maple, cherry, walnut, oak.
function diskTint(d: i32): vec3 {
    if d == 0 { return vec3(0.95, 0.83, 0.60); }
    if d == 1 { return vec3(0.70, 0.26, 0.16); }
    if d == 2 { return vec3(0.42, 0.24, 0.13); }
    return vec3(0.85, 0.64, 0.36);
}

// How many disks bigger than d sit on this peg: the slot height of d.
function countBigger(dp: *const i32, peg: i32, d: i32, skip: i32): i32 {
    var c: i32 = 0;
    var e: i32 = 0;
    while e < DISKS {
        if e != d && e != skip && *(dp + e) == peg && e > d {
            c = c + 1;
        }
        e = e + 1;
    }
    return c;
}

// Draw one cylinder standing upright, centred on its base.
function drawUpright(radius: f32, height: f32, x: f32, y: f32, z: f32, tint: vec3): void {
    glPushMatrix();
    glTranslatef(x, y, z);
    glRotatef(-90.0, 1.0, 0.0, 0.0);
    glColor3f(tint.x, tint.y, tint.z);
    drawCylinder(radius, height);
    glPopMatrix();
}

function drawScene(elapsed: i32): void {
    var dp: i32[4];
    var e: i32 = 0;
    while e < DISKS {
        dp[e] = 0;
        e = e + 1;
    }

    let ms: i32 = elapsed % (TOTAL_MOVES * MOVE_MS);
    let moveIdx: i32 = ms / MOVE_MS;
    let frac: f32 = (ms % MOVE_MS) as f32 / MOVE_MS as f32;
    let flying: i32 = mvDisk[moveIdx];

    e = 0;
    while e < moveIdx {
        dp[mvDisk[e]] = mvTo[e];
        e = e + 1;
    }

    let srcPeg: i32 = mvFrom[moveIdx];
    let dstPeg: i32 = mvTo[moveIdx];
    let srcSlot: i32 = countBigger(dp.as_ptr(), srcPeg, flying, flying);
    let dstSlot: i32 = countBigger(dp.as_ptr(), dstPeg, flying, flying);

    // Round wooden platform
    drawUpright(1.45, 0.14, 0.0, -0.07, 0.0, vec3(0.36, 0.23, 0.14));

    // Pegs
    let pegTone: vec3 = vec3(0.48, 0.31, 0.17);
    var p: i32 = 0;
    while p < 3 {
        drawUpright(0.055, PEG_HEIGHT, pegX(p), 0.0, 0.0, pegTone);
        p = p + 1;
    }

    // Disks, one of them in flight
    var d: i32 = 0;
    while d < DISKS {
        let tint: vec3 = diskTint(d);
        let r: f32 = diskRadius(d);
        if d == flying {
            let x0: f32 = pegX(srcPeg);
            let x1: f32 = pegX(dstPeg);
            let y0: f32 = 0.09 + srcSlot as f32 * DISK_GAP;
            let y1: f32 = 0.09 + dstSlot as f32 * DISK_GAP;
            let x: f32 = x0 + (x1 - x0) * frac;
            let y: f32 = y0 + (y1 - y0) * frac + 0.45 * sinf(frac * PI);
            drawUpright(r, DISK_HEIGHT, x, y, 0.0, tint);
        } else {
            let slot: i32 = countBigger(dp.as_ptr(), dp[d], d, flying);
            drawUpright(r, DISK_HEIGHT, pegX(dp[d]), 0.09 + slot as f32 * DISK_GAP, 0.0, tint);
        }
        d = d + 1;
    }
}

// Drifting mist motes: soft translucent points that always face the camera.
function drawMist(elapsed: i32): void {
    let t: f32 = elapsed as f32 * 0.001;
    var i: i32 = 0;
    while i < 160 {
        let fi: f32 = i as f32;
        let seed: f32 = texRand(i as u32, 7);
        let seed2: f32 = texRand(i as u32, 991);
        let px: f32 = sinf(fi * 1.7 + t * 0.22) * 2.0 + (seed - 0.5) * 1.0;
        let pz: f32 = cosf(fi * 2.3 + t * 0.15) * 1.3 + (seed2 - 0.5) * 1.0;
        let py: f32 = 0.02 + 1.05 * (0.5 + 0.5 * sinf(fi * 0.9 + t * 0.30));
        let size: f32 = 30.0 + 80.0 * seed;
        let alpha: f32 = 0.030 + 0.045 * seed2;

        glPointSize(size);
        glColor4f(0.90, 0.94, 0.98, alpha);
        glBegin(GL_POINTS);
        glVertex3f(px, py, pz);
        glEnd();
        i = i + 1;
    }
}

function display(): void {
    glClear(0x00004000 | 0x00000100);
    glLoadIdentity();

    let elapsed: i32 = glutGet(GLUT_ELAPSED_TIME);
    let t: f32 = elapsed as f32 * 0.001;

    // Orbit the camera around the target.
    let yaw: f32 = keyYaw + t * 6.0;
    let pitch: f32 = keyPitch;
    let dist: f32 = 4.60;
    let yr: f32 = yaw * 0.01745329;
    let pr: f32 = pitch * 0.01745329;
    let cp: f32 = cosf(pr);
    let sp: f32 = sinf(pr);
    let cy: f32 = cosf(yr);
    let sy: f32 = sinf(yr);
    camPos.x = camTarget.x + dist * cp * sy;
    camPos.y = camTarget.y + dist * sp;
    camPos.z = camTarget.z + dist * cp * cy;

    // Aim the camera at the target from the orbiting position.
    gluLookAt(
        camPos.x as f64, camPos.y as f64, camPos.z as f64,
        camTarget.x as f64, camTarget.y as f64, camTarget.z as f64,
        0.0, 1.0, 0.0
    );

    drawScene(elapsed);

    glDisable(GL_LIGHTING);
    glDisable(GL_TEXTURE_2D);
    glEnable(GL_POINT_SMOOTH);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDepthMask(0);
    drawMist(elapsed);
    glDepthMask(1);
    glDisable(GL_BLEND);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_LIGHTING);

    glutSwapBuffers();
}

function reshape(width: i32, height: i32): void {
    if height == 0 {
        height = 1;
    }
    glViewport(0, 0, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glPerspective(45.0, width as f64 / height as f64, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
}

function special(key: i32, x: i32, y: i32): void {
    if key == GLUT_KEY_LEFT { keyYaw = keyYaw - 4.0; }
    if key == GLUT_KEY_RIGHT { keyYaw = keyYaw + 4.0; }
    if key == GLUT_KEY_UP { keyPitch = keyPitch + 3.0; }
    if key == GLUT_KEY_DOWN { keyPitch = keyPitch - 3.0; }
    if keyPitch > 50.0 { keyPitch = 50.0; }
    if keyPitch < -10.0 { keyPitch = -10.0; }
    glutPostRedisplay();
}

// GLUT timers are one-shot: re-arm every frame so the scene keeps animating.
function tick(value: i32): void {
    glutTimerFunc(16, tick, 0);
    glutPostRedisplay();
}

function init(): void {
    glClearColor(0.42, 0.47, 0.52, 1.0);
    glEnable(GL_DEPTH_TEST);

    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    let ambient: f32[4] = { 0.55, 0.55, 0.58, 1.0 };
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.as_ptr());
    let lightPos: f32[4] = { 2.5, 4.0, 3.0, 0.0 };
    glLightfv(GL_LIGHT0, GL_POSITION, lightPos.as_ptr());

    glEnable(GL_COLOR_MATERIAL);
    glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);

    glEnable(GL_FOG);
    glFogi(GL_FOG_MODE, GL_LINEAR);
    glFogf(GL_FOG_START, 9.0);
    glFogf(GL_FOG_END, 26.0);
    let fogColor: f32[4] = { 0.42, 0.47, 0.52, 1.0 };
    glFogfv(GL_FOG_COLOR, fogColor.as_ptr());

    buildWoodTexture();
    var texId: u32 = 0;
    glGenTextures(1, &texId);
    glBindTexture(GL_TEXTURE_2D, texId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, TEX_SIZE, TEX_SIZE, 0, GL_RGB, GL_UNSIGNED_BYTE, woodTex.as_ptr());
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    glEnable(GL_TEXTURE_2D);

    mvCount = 0;
    planMoves(DISKS, 0, 0, 2, 1);
}

function main(): i32 {
    let argc: i32 = 1;
    let argv: *const u8 = "hanoi3d";

    glutInit(argc, argv);
    glutInitDisplayMode(0x0002 | 0x0000 | 0x0010);
    glutInitWindowSize(900, 700);
    glutCreateWindow("3D Misty Hanoi Tower");

    init();
    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutSpecialFunc(special);
    glutTimerFunc(16, tick, 0);

    printf("Arrow keys rotate the tower. Watching the solve.\n");
    glutMainLoop();
    return 0;
}
