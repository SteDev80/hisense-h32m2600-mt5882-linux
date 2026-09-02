#include <X11/Xlib.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void draw_button(Display *dpy, Window win, GC gc, int pressed)
{
    XSetForeground(dpy, gc, pressed ? 0x1f4f78 : 0x2879b9);
    XFillRectangle(dpy, win, gc, 0, 0, 132, 36);
    XSetForeground(dpy, gc, 0xffffff);
    XDrawString(dpy, win, gc, 36, 23, "START", 5);
}

int main(void)
{
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy)
        return 1;

    int screen = DefaultScreen(dpy);
    int width = DisplayWidth(dpy, screen);
    int height = DisplayHeight(dpy, screen);
    XSetWindowAttributes attr;
    memset(&attr, 0, sizeof(attr));
    attr.override_redirect = True;
    attr.event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask;

    Window win = XCreateWindow(dpy, RootWindow(dpy, screen), 8, height - 44,
        132, 36, 1, CopyFromParent, InputOutput, CopyFromParent,
        CWOverrideRedirect | CWEventMask, &attr);
    XStoreName(dpy, win, "H32 Start");
    XMapRaised(dpy, win);

    GC gc = XCreateGC(dpy, win, 0, NULL);
    int pressed = 0;
    for (;;) {
        XEvent ev;
        XNextEvent(dpy, &ev);
        if (ev.type == Expose) {
            draw_button(dpy, win, gc, pressed);
        } else if (ev.type == ButtonPress && ev.xbutton.button == Button1) {
            pressed = 1;
            draw_button(dpy, win, gc, pressed);
        } else if (ev.type == ButtonRelease && ev.xbutton.button == Button1) {
            pressed = 0;
            draw_button(dpy, win, gc, pressed);
            if (fork() == 0) {
                execl("/usr/local/bin/h32-start-menu", "h32-start-menu", (char *)0);
                _exit(127);
            }
        }
    }
}
