/*
##########################################################################################
A program to control Pi-pan.
 
Pi-Pan details;
www.kickstarter.com/projects/1842571016/pi-pan-a-pan-tilt-for-raspberry-pi-camera
www.openelectrons.com
 
Copyright (C) 2013 Mark Williams
www.ozzmaker.com
 
Reqires Serverblaster
If the servos do not move, check that they have been defined correctly below.
##########################################################################################
 
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.
 
This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Library General Public License for more details.
 
You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the Free
Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
MA 02111-1307, USA
*/
 
#include <stdio.h>
 
#include <string.h>
#include <sys/time.h>
#include <termios.h>
#include <stdlib.h>
#include <signal.h>
 
#define TILT_SERVO 5
#define PAN_SERVO 6
 
static struct termios g_old_kbd_mode;
FILE *fp;
 
// detect key press
static int kbhit(void){
    struct timeval timeout;
    fd_set read_handles;
    int status;
 
    // check stdin (fd 0) for activity
    FD_ZERO(&read_handles);
    FD_SET(0, &read_handles);
    timeout.tv_sec = timeout.tv_usec = 0;
    status = select(0 + 1, &read_handles, NULL, NULL, &timeout);
    return status;
}
 
// put things as they were before we leave..!!!
static void old_attr(void){
    tcsetattr(0, TCSANOW, &g_old_kbd_mode);
}
 
void  INThandler(int sig)
{
    fclose(fp);
        signal(sig, SIG_IGN);
        exit(0);
}
 
void servoblaster(int server, int  pulseWidth){
       fprintf(fp, "%i=%i\n",server,pulseWidth);
       fflush(fp);
}
 
// main function
int main( void ){
 
    char ch;
    static char init;
    struct termios new_kbd_mode;
    int tilt=150;
    int pan=150;
 
    fp = fopen("/dev/servoblaster", "w");
    if (fp == NULL) {
        printf("Error opening file\n");
        exit(0);
    }
 
    if(init)
        return;
    // put keyboard (stdin, actually) in raw, unbuffered mode
    tcgetattr(0, &g_old_kbd_mode);
    memcpy(&new_kbd_mode, &g_old_kbd_mode, sizeof(struct termios));
 
    new_kbd_mode.c_lflag &= ~(ICANON | ECHO);
    new_kbd_mode.c_cc[VTIME] = 0;
    new_kbd_mode.c_cc[VMIN] = 1;
    tcsetattr(0, TCSANOW, &new_kbd_mode);
    atexit(old_attr);
 
    // stat Pi-pan in its neutral position
    servoblaster(TILT_SERVO,150);
    servoblaster(PAN_SERVO,150);
 
    printf("\n\n\nUse 'w','s','a' and 'd' keys to conrol the movement of Pi-pan.\n");
    printf("The spacebar will reset Pi-pan to its  neutral position.\n");
    printf("\n\n");
 
    while (!kbhit()){
        // getting the pressed key...
        ch = getchar();
    switch (ch){
    case 's':
        printf("Down\n");
        tilt++;
        if (tilt>180)tilt=180;
        servoblaster(TILT_SERVO,tilt);
        break;
    case 'w':
        printf("Up\n");
        tilt--;
        if (tilt<80)tilt=80;         servoblaster(TILT_SERVO,tilt);      break;  case 'a':       printf("Left\n");       pan++;      if (pan>200)pan=200;
        servoblaster(PAN_SERVO,pan);
        break;
    case 'd':
        printf("Right\n");
        pan--;
        if (pan<50)pan=50;
        servoblaster(PAN_SERVO,pan);
        break;
    case ' ':
        printf("Reset\n");
        tilt=150;
        pan=150;
        servoblaster(TILT_SERVO,tilt);
        servoblaster(PAN_SERVO,pan);
        break;
        }
    }
}
