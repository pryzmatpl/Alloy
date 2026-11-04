// 3D misty Hanoi tower rendered with freeglut/OpenGL.
// The emitted C program must:
//   - include <GL/freeglut.h> and <stdio.h>
//   - set glClearColor to (0.15, 0.18, 0.22, 1.0)
//   - enable GL_DEPTH_TEST and GL_FOG; set fog color to the same as clear color
//   - use GL_LINEAR fog: GL_FOG_START=2.0, GL_FOG_END=15.0, GL_FOG_DENSITY=0.05
//   - draw a base platform, three pegs, and 4 disks stacked on the left peg
//   - use glColor3f for wood colors (DO NOT enable GL_LIGHTING; plain vertex colors avoid black objects)
//   - use glutSolidCylinder (from freeglut) for both disks and pegs if possible
//   - rotate the scene with arrow keys via glutSpecialFunc and GLUT_KEY_LEFT/RIGHT/UP/DOWN
//   - compile with: cc -o hanoi3d hanoi3d.c -lGL -lGLU -lglut -lm

extern "C" {
    function printf(fmt: *const u8, ...): i32;

    function glutInit(argc: i32, argv: *const u8): void;
    function glutInitDisplayMode(mode: u32): void;
    function glutInitWindowSize(width: i32, height: i32): void;
    function glutCreateWindow(title: *const u8): i32;
    function glutDisplayFunc(cb: *const u8): void;
    function glutSpecialFunc(cb: *const u8): void;
    function glutReshapeFunc(cb: *const u8): void;
    function glutMainLoop(): void;
    function glutPostRedisplay(): void;
    function glutSwapBuffers(): void;
    function glutSolidSphere(radius: f64, slices: i32, stacks: i32): void;
    function glutSolidCube(size: f64): void;

    function glClear(mask: u32): void;
    function glClearColor(r: f32, g: f32, b: f32, a: f32): void;
    function glLoadIdentity(): void;
    function glTranslatef(x: f32, y: f32, z: f32): void;
    function glRotatef(angle: f32, x: f32, y: f32, z: f32): void;
    function glPushMatrix(): void;
    function glPopMatrix(): void;
    function glScalef(x: f32, y: f32, z: f32): void;
    function glColor3f(r: f32, g: f32, b: f32): void;
    function glEnable(cap: u32): void;
    function glMatrixMode(mode: u32): void;
    function glViewport(x: i32, y: i32, width: i32, height: i32): void;
    function gluPerspective(fovy: f64, aspect: f64, zNear: f64, zFar: f64): void;
    function glFogi(pname: u32, param: i32): void;
    function glFogf(pname: u32, param: f32): void;
    function glFogfv(pname: u32, params: *const f32): void;
}

let cameraX: f32 = 20.0;
let cameraY: f32 = -30.0;

function drawDisk(radius: f32, height: f32): void {
    glPushMatrix();
    glScalef(radius, height, radius);
    glutSolidSphere(1.0, 24, 24);
    glPopMatrix();
}

function drawPeg(): void {
    glPushMatrix();
    glScalef(0.08, 1.2, 0.08);
    glutSolidCube(1.0);
    glPopMatrix();
}

function drawBase(): void {
    glPushMatrix();
    glTranslatef(0.0, -0.05, 0.0);
    glScalef(2.6, 0.1, 0.9);
    glutSolidCube(1.0);
    glPopMatrix();
}

function drawScene(): void {
    glColor3f(0.45, 0.28, 0.12);
    drawBase();

    glColor3f(0.55, 0.35, 0.15);
    glPushMatrix();
    glTranslatef(-1.0, 0.6, 0.0);
    drawPeg();
    glPopMatrix();

    glPushMatrix();
    glTranslatef(0.0, 0.6, 0.0);
    drawPeg();
    glPopMatrix();

    glPushMatrix();
    glTranslatef(1.0, 0.6, 0.0);
    drawPeg();
    glPopMatrix();

    glColor3f(0.75, 0.45, 0.15);
    glPushMatrix();
    glTranslatef(-1.0, 0.1, 0.0);
    drawDisk(0.45, 0.08);
    glPopMatrix();

    glPushMatrix();
    glTranslatef(-1.0, 0.26, 0.0);
    drawDisk(0.36, 0.08);
    glPopMatrix();

    glPushMatrix();
    glTranslatef(-1.0, 0.42, 0.0);
    drawDisk(0.27, 0.08);
    glPopMatrix();

    glPushMatrix();
    glTranslatef(-1.0, 0.58, 0.0);
    drawDisk(0.18, 0.08);
    glPopMatrix();
}

function display(): void {
    glClear(0x00004000 | 0x00000100);
    glLoadIdentity();
    glTranslatef(0.0, -0.3, -4.5);
    glRotatef(cameraX, 1.0, 0.0, 0.0);
    glRotatef(cameraY, 0.0, 1.0, 0.0);
    drawScene();
    glutSwapBuffers();
}

function reshape(width: i32, height: i32): void {
    if height == 0 { height = 1; }
    glViewport(0, 0, width, height);
    glMatrixMode(0x1701);
    glLoadIdentity();
    gluPerspective(45.0, 800.0 / 600.0, 0.1, 100.0);
    glMatrixMode(0x1700);
}

function special(key: i32, x: i32, y: i32): void {
    if key == 100 { cameraY = cameraY - 3.0; }
    if key == 102 { cameraY = cameraY + 3.0; }
    if key == 101 { cameraX = cameraX - 3.0; }
    if key == 103 { cameraX = cameraX + 3.0; }
    glutPostRedisplay();
}

function init(): void {
    glClearColor(0.15, 0.18, 0.22, 1.0);
    glEnable(0x0B71);
    glEnable(0x0B60);
    glFogi(0x0B65, 0x2601);
    glFogf(0x0B66, 2.0);
    glFogf(0x0B67, 15.0);
    glFogfv(0x0B66, 0);
}

function main(): i32 {
    let argc: i32 = 1;
    let argv: *const u8 = "hanoi3d";

    glutInit(argc, argv);
    glutInitDisplayMode(0x0002 | 0x0000 | 0x0010);
    glutInitWindowSize(800, 600);
    glutCreateWindow("3D Misty Hanoi Tower");

    init();
    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutSpecialFunc(special);

    printf("Use arrow keys to rotate the tower.\n");
    glutMainLoop();
    return 0;
}
