// 3D misty Hanoi tower.
//
// The emitted C program must:
//   - include <GL/freeglut.h>, <GL/glu.h>, <math.h> and <stdio.h>
//   - link with -lGL -lGLU -lglut -lm
//   - build a 64x64 procedural wood texture (vertical grain + dark knots) and
//     map it onto every cylinder through a GLU quadric, so the wood shows
//     grain and speckles instead of flat colour
//   - tint each disk with a different wood tone (GL_MODULATE + glColor3f)
//   - enable GL_FOG with a pale sky colour for depth mist
//   - add drifting translucent mist puffs (low alpha spheres, blending on)
//   - animate the real Hanoi solution: disks fly between pegs on an arc
//   - rotate the camera with the arrow keys and slowly orbit on its own
//
// The GLU quadric handle is an opaque GLUquadric*; Alloy spells it *mut u8.
//
// The GL_* constants below are named after the OpenGL constants of the same
// name and value. In the emitted C, use the ones from <GL/gl.h> directly and
// do not redefine them.

extern "C" {
    function printf(fmt: *const u8, ...): i32;
    function sinf(x: f32): f32;
    function cosf(x: f32): f32;
    function sqrtf(x: f32): f32;

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
    function glutSolidSphere(radius: f64, slices: i32, stacks: i32): void;

    function glClear(mask: u32): void;
    function glClearColor(r: f32, g: f32, b: f32, a: f32): void;
    function glLoadIdentity(): void;
    function glTranslatef(x: f32, y: f32, z: f32): void;
    function glRotatef(angle: f32, x: f32, y: f32, z: f32): void;
    function glPushMatrix(): void;
    function glPopMatrix(): void;
    function glColor3f(r: f32, g: f32, b: f32): void;
    function glColor4f(r: f32, g: f32, b: f32, a: f32): void;
    function glEnable(cap: u32): void;
    function glDisable(cap: u32): void;
    function glBlendFunc(sf: u32, df: u32): void;
    function glDepthMask(flag: u32): void;
    function glMatrixMode(mode: u32): void;
    function glViewport(x: i32, y: i32, width: i32, height: i32): void;
    function gluPerspective(fovy: f64, aspect: f64, zNear: f64, zFar: f64): void;
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
    function glPointSize(size: f32): void;

    function gluNewQuadric(): *mut u8;
    function gluQuadricNormals(q: *mut u8, mode: u32): void;
    function gluQuadricTexture(q: *mut u8, on: u32): void;
    function gluCylinder(q: *mut u8, rBase: f64, rTop: f64, height: f64, slices: i32, stacks: i32): void;
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
let GLUT_ELAPSED_TIME: i32 = 0x02BC;
let GLUT_KEY_LEFT: i32 = 100;
let GLUT_KEY_RIGHT: i32 = 102;
let GLUT_KEY_UP: i32 = 101;
let GLUT_KEY_DOWN: i32 = 103;
let GLU_SMOOTH: u32 = 0x0001;
let GL_POINT_SMOOTH: u32 = 0x0B11;

let DISKS: i32 = 4;
let TEX_SIZE: i32 = 64;
let MOVE_MS: i32 = 800;
let TOTAL_MOVES: i32 = 15;
let PEG_X0: f32 = -1.15;
let PEG_X1: f32 = 0.0;
let PEG_X2: f32 = 1.15;
let PEG_HEIGHT: f32 = 1.05;
let DISK_HEIGHT: f32 = 0.13;
let DISK_GAP: f32 = 0.15;

var woodTex: u8[12288];
var mvFrom: i32[16];
var mvTo: i32[16];
var mvDisk: i32[16];
var mvCount: i32 = 0;
var quad: *mut u8 = null;
var keyYaw: f32 = 0.0;
var keyPitch: f32 = 0.0;
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

// Vertical wood grain with dark knots and speckles.
function buildWoodTexture(): void {
    var px: i32 = 0;
    while px < TEX_SIZE {
        var py: i32 = 0;
        while py < TEX_SIZE {
            let fx: f32 = px as f32;
            let fy: f32 = py as f32;
            let n: f32 = texRand(px as u32, py as u32);
            let knot: f32 = texRand((px / 4) as u32, (py / 4) as u32);
            let grain: f32 = sinf(fx * 0.85 + 2.5 * sinf(fy * 0.11) + 1.5 * (n - 0.5));
            let g: f32 = 0.55 + 0.45 * grain;
            var rr: f32 = 0.34 + 0.50 * g;
            var gg: f32 = 0.19 + 0.36 * g;
            var bb: f32 = 0.08 + 0.20 * g;
            if knot > 0.94 {
                rr = rr * 0.28;
                gg = gg * 0.24;
                bb = bb * 0.20;
            }
            if n > 0.985 {
                rr = rr * 0.45;
                gg = gg * 0.42;
                bb = bb * 0.38;
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
    if d == 0 { return vec3(0.93, 0.79, 0.55); }
    if d == 1 { return vec3(0.68, 0.28, 0.17); }
    if d == 2 { return vec3(0.44, 0.26, 0.14); }
    return vec3(0.82, 0.62, 0.36);
}

// How many disks bigger than d sit on this peg (the slot height of d).
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
    glPushMatrix();
    glTranslatef(0.0, -0.07, 0.0);
    glRotatef(-90.0, 1.0, 0.0, 0.0);
    glColor3f(0.38, 0.24, 0.15);
    gluCylinder(quad, 1.70, 1.70, 0.14, 48, 2);
    glPopMatrix();

    // Pegs
    let pegTone: vec3 = vec3(0.50, 0.32, 0.17);
    var p: i32 = 0;
    while p < 3 {
        glPushMatrix();
        glTranslatef(pegX(p), 0.0, 0.0);
        glRotatef(-90.0, 1.0, 0.0, 0.0);
        glColor3f(pegTone.x, pegTone.y, pegTone.z);
        gluCylinder(quad, 0.055, 0.055, PEG_HEIGHT, 20, 2);
        glPopMatrix();
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
            let y: f32 = y0 + (y1 - y0) * frac + 0.45 * sinf(frac * 3.14159265);
            glPushMatrix();
            glTranslatef(x, y, 0.0);
            glRotatef(-90.0, 1.0, 0.0, 0.0);
            glColor3f(tint.x, tint.y, tint.z);
            gluCylinder(quad, r, r, DISK_HEIGHT, 32, 2);
            glPopMatrix();
        } else {
            let slot: i32 = countBigger(dp.as_ptr(), dp[d], d, flying);
            glPushMatrix();
            glTranslatef(pegX(dp[d]), 0.09 + slot as f32 * DISK_GAP, 0.0);
            glRotatef(-90.0, 1.0, 0.0, 0.0);
            glColor3f(tint.x, tint.y, tint.z);
            gluCylinder(quad, r, r, DISK_HEIGHT, 32, 2);
            glPopMatrix();
        }
        d = d + 1;
    }
}

// Soft drifting mist: translucent round points, always facing the camera.
function drawMist(elapsed: i32): void {
    let t: f32 = elapsed as f32 * 0.001;
    var i: i32 = 0;
    while i < 120 {
        let fi: f32 = i as f32;
        let seed: f32 = texRand(i as u32, 7);
        let seed2: f32 = texRand(i as u32, 991);
        let px: f32 = sinf(fi * 1.7 + t * 0.22) * 2.1 + (seed - 0.5) * 0.9;
        let pz: f32 = cosf(fi * 2.3 + t * 0.15) * 1.4 + (seed2 - 0.5) * 0.9;
        let py: f32 = 0.05 + 0.95 * (0.5 + 0.5 * sinf(fi * 0.9 + t * 0.30));
        let size: f32 = 40.0 + 90.0 * seed;
        let alpha: f32 = 0.020 + 0.030 * seed2;

        glPointSize(size);
        glColor4f(0.88, 0.92, 0.96, alpha);
        glBegin(0x0000);
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
    gluPerspective(45.0, width as f64 / height as f64, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
}

function special(key: i32, x: i32, y: i32): void {
    if key == GLUT_KEY_LEFT { keyYaw = keyYaw - 4.0; }
    if key == GLUT_KEY_RIGHT { keyYaw = keyYaw + 4.0; }
    if key == GLUT_KEY_UP { keyPitch = keyPitch + 3.0; }
    if key == GLUT_KEY_DOWN { keyPitch = keyPitch - 3.0; }
    if keyPitch > 45.0 { keyPitch = 45.0; }
    if keyPitch < -20.0 { keyPitch = -20.0; }
    glutPostRedisplay();
}

// GLUT timers are one-shot: re-arm every frame so the scene keeps animating.
function tick(value: i32): void {
    glutTimerFunc(16, tick, 0);
    glutPostRedisplay();
}

function init(): void {
    glClearColor(0.36, 0.41, 0.46, 1.0);
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
    glFogf(GL_FOG_START, 4.5);
    glFogf(GL_FOG_END, 16.0);
    let fogColor: f32[4] = { 0.36, 0.41, 0.46, 1.0 };
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

    quad = gluNewQuadric();
    gluQuadricNormals(quad, GLU_SMOOTH);
    gluQuadricTexture(quad, 1);

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
