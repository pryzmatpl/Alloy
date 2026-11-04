// 3D misty Hanoi tower.
//
// The emitted C program must:
//   - include <GL/freeglut.h>, <GL/glu.h>, <math.h> and <stdio.h>
//   - link with -lGL -lGLU -lglut -lm
//   - build a 64x64 procedural wood texture (rings + dark speckles) and map it
//     onto every cylinder through a GLU quadric, so the wood shows grain
//   - tint each disk with a different wood tone (GL_MODULATE + glColor3f)
//   - enable GL_FOG with a pale sky colour for depth mist
//   - add drifting translucent mist puffs (low alpha spheres, blending on)
//   - animate the real Hanoi solution: disks fly between pegs on an arc
//   - rotate the camera with the arrow keys and slowly orbit on its own
//
// The GLU quadric handle is an opaque GLUquadric*; Alloy spells it *mut u8.

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

    function gluNewQuadric(): *mut u8;
    function gluQuadricNormals(q: *mut u8, mode: u32): void;
    function gluQuadricTexture(q: *mut u8, on: u32): void;
    function gluCylinder(q: *mut u8, rBase: f64, rTop: f64, height: f64, slices: i32, stacks: i32): void;
}

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

function buildWoodTexture(): void {
    var px: i32 = 0;
    while px < TEX_SIZE {
        var py: i32 = 0;
        while py < TEX_SIZE {
            let fx: f32 = px as f32;
            let fy: f32 = py as f32;
            let n: f32 = texRand(px as u32, py as u32);
            let rings: f32 = sinf(fy * 0.85 + 2.5 * sinf(fx * 0.11) + 1.5 * (n - 0.5));
            let g: f32 = 0.55 + 0.45 * rings;
            var rr: f32 = 0.30 + 0.55 * g;
            var gg: f32 = 0.17 + 0.40 * g;
            var bb: f32 = 0.07 + 0.22 * g;
            if n > 0.97 {
                rr = rr * 0.30;
                gg = gg * 0.30;
                bb = bb * 0.30;
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

function diskTint(d: i32): vec3 {
    if d == 0 { return vec3(0.95, 0.82, 0.58); }
    if d == 1 { return vec3(0.72, 0.33, 0.20); }
    if d == 2 { return vec3(0.52, 0.33, 0.18); }
    return vec3(0.86, 0.68, 0.42);
}

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

function drawCylinder(radius: f32, height: f32, y: f32, tint: vec3): void {
    glPushMatrix();
    glTranslatef(0.0, y, 0.0);
    glRotatef(-90.0, 1.0, 0.0, 0.0);
    glColor3f(tint.x, tint.y, tint.z);
    gluCylinder(quad, radius, radius, height, 32, 2);
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

    // Platform
    glPushMatrix();
    glTranslatef(0.0, -0.07, 0.0);
    glRotatef(-90.0, 1.0, 0.0, 0.0);
    glColor3f(0.40, 0.27, 0.18);
    gluCylinder(quad, 1.70, 1.70, 0.14, 48, 2);
    glPopMatrix();

    // Pegs
    let pegTone: vec3 = vec3(0.55, 0.38, 0.22);
    let p: i32 = 0;
    while p < 3 {
        glPushMatrix();
        glTranslatef(pegX(p), 0.0, 0.0);
        glRotatef(-90.0, 1.0, 0.0, 0.0);
        glColor3f(pegTone.x, pegTone.y, pegTone.z);
        gluCylinder(quad, 0.055, 0.055, PEG_HEIGHT, 20, 2);
        glPopMatrix();
        p = p + 1;
    }

    // Disks
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

function drawMist(elapsed: i32): void {
    let t: f32 = elapsed as f32 * 0.001;
    var i: i32 = 0;
    while i < 14 {
        let fi: f32 = i as f32;
        let px: f32 = sinf(fi * 1.7 + t * 0.25) * 1.75;
        let pz: f32 = cosf(fi * 2.3 + t * 0.18) * 1.10;
        let py: f32 = 0.12 + 0.48 * (0.5 + 0.5 * sinf(fi * 0.9 + t * 0.35));
        let rad: f32 = 0.34 + 0.30 * (0.5 + 0.5 * sinf(fi * 3.1));
        glPushMatrix();
        glTranslatef(px, py, pz);
        glColor4f(0.78, 0.82, 0.88, 0.055);
        glutSolidSphere(rad, 16, 12);
        glPopMatrix();
        i = i + 1;
    }
}

function display(): void {
    glClear(0x00004000 | 0x00000100);
    glLoadIdentity();

    let elapsed: i32 = glutGet(0x02BC);
    let t: f32 = elapsed as f32 * 0.001;

    let yaw: f32 = keyYaw + t * 6.0;
    let pitch: f32 = keyPitch;
    let dist: f32 = 4.20;
    let ry: f32 = cosf(yaw * 0.01745329);
    let sx: f32 = sinf(yaw * 0.01745329);
    let rp: f32 = cosf(pitch * 0.01745329);
    let sp: f32 = sinf(pitch * 0.01745329);
    camPos.x = camTarget.x + dist * ry * rp;
    camPos.y = camTarget.y + dist * sp;
    camPos.z = camTarget.z + dist * sx * rp;

    glTranslatef(-camPos.x, -camPos.y, -camPos.z);
    glRotatef(-pitch, 1.0, 0.0, 0.0);
    glRotatef(-yaw, 0.0, 1.0, 0.0);

    drawScene(elapsed);

    glDisable(0x0B50);
    glEnable(0x0BE2);
    glBlendFunc(0x0302, 0x0303);
    glDepthMask(0);
    drawMist(elapsed);
    glDepthMask(1);
    glDisable(0x0BE2);
    glEnable(0x0B50);

    glutSwapBuffers();
}

function reshape(width: i32, height: i32): void {
    if height == 0 {
        height = 1;
    }
    glViewport(0, 0, width, height);
    glMatrixMode(0x1701);
    glLoadIdentity();
    gluPerspective(45.0, width as f64 / height as f64, 0.1, 100.0);
    glMatrixMode(0x1700);
}

function special(key: i32, x: i32, y: i32): void {
    if key == 100 { keyYaw = keyYaw - 4.0; }
    if key == 102 { keyYaw = keyYaw + 4.0; }
    if key == 101 { keyPitch = keyPitch + 3.0; }
    if key == 103 { keyPitch = keyPitch - 3.0; }
    if keyPitch > 45.0 { keyPitch = 45.0; }
    if keyPitch < -20.0 { keyPitch = -20.0; }
    glutPostRedisplay();
}

function tick(value: i32): void {
    glutPostRedisplay();
}

function init(): void {
    glClearColor(0.36, 0.41, 0.46, 1.0);
    glEnable(0x0B71);

    glEnable(0x0B50);
    glEnable(0x4000);
    let ambient: f32[4] = { 0.55, 0.55, 0.58, 1.0 };
    glLightModelfv(0x0B57, ambient.as_ptr());
    let lightPos: f32[4] = { 2.5, 4.0, 3.0, 0.0 };
    glLightfv(0x4000, 0x1202, lightPos.as_ptr());

    glEnable(0x0B57);
    glColorMaterial(0x0404, 0x1601);

    glEnable(0x0B60);
    glFogi(0x0B65, 0x2601);
    glFogf(0x0B63, 3.0);
    glFogf(0x0B64, 13.0);
    let fogColor: f32[4] = { 0.36, 0.41, 0.46, 1.0 };
    glFogfv(0x0B66, fogColor.as_ptr());

    buildWoodTexture();
    var texId: u32 = 0;
    glGenTextures(1, &texId);
    glBindTexture(0x0DE1, texId);
    glTexParameteri(0x0DE1, 0x2801, 0x2601);
    glTexParameteri(0x0DE1, 0x2800, 0x2601);
    glTexParameteri(0x0DE1, 0x2802, 0x2901);
    glTexParameteri(0x0DE1, 0x2803, 0x2901);
    glTexImage2D(0x0DE1, 0, 0x1907, TEX_SIZE, TEX_SIZE, 0, 0x1907, 0x1401, woodTex.as_ptr());
    glTexEnvi(0x2300, 0x2200, 0x2100);
    glEnable(0x0DE1);

    quad = gluNewQuadric();
    gluQuadricNormals(quad, 0x0001);
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
