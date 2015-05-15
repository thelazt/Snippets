/*
 * Simple "try", which resumes outside of block after error using get-/setcontext()
 *
 * $ gcc -O3 try.c && ./a.out	or
 * $ gcc -O3 -DUSETRY rpr_main.c && ./a.out
 * 	A0
 * 	B0
 * 	C1
 * 	D1
 * 	E1
 *
 * $ gcc -O3 -DFAIL try.c && ./a.out
 * 	A0
 * 	B0
 * 	C1
 * 	SIGHANDLER: Caught 8
 * 	SIGHANDLER: Fatal! Exit!
 *
 * $ gcc -O3 -DFAIL -DUSETRY try.c && ./a.out
 * 	A0
 * 	B0
 * 	C1
 * 	SIGHANDLER: Caught 8
 * 	SIGHANDLER: Restoring try in try.c:75
 * 	E0
 *
 * Drawbacks: Won't free allocated memory, release locks etc.
 */
#include <stdio.h>
#include <ucontext.h>
#include <unistd.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/types.h>
#include <stdlib.h>


struct mycontext {
	volatile bool failed;
	volatile bool installed;
	char * file;
	int line;
	ucontext_t context;
};

__thread struct mycontext thiscontext;

#ifdef USETRY
#define try for (thiscontext = (struct mycontext) {.installed = true, .failed = false, .file=__FILE__, .line=__LINE__ }; thiscontext.installed==true && getcontext((struct ucontext *)&thiscontext.context) == 0 && thiscontext.failed==false ; thiscontext.installed=false)
#else
#define try
#endif

void sig_handler(int sig){
	printf("\e[31mSIGHANDLER: Caught %d\e[0m\n",sig);
	if (thiscontext.installed==true){
		thiscontext.failed=true;
		thiscontext.installed=false;
		printf("\e[31mSIGHANDLER: Restoring try in %s:%d\e[0m\n",thiscontext.file,thiscontext.line);
		setcontext((const struct ucontext *)&thiscontext.context);
	}
	else{
		printf("\e[31mSIGHANDLER: Fatal! Exit!\e[0m\n",sig);
		exit(1);
	}
}


int main( int argc, char *argv[] ){
	int x=0.0;
	// install sig handler
	signal (SIGFPE, sig_handler);
	// Our tool
	printf("A%d\n",x);
	try {
		printf("B%d\n",x);
		x++;
		printf("C%d\n",x);
#ifdef FAIL
		x/=x-1;
#endif
		printf("D%d\n",x);
	}
	printf("E%d\n",x);
	return 0;
}
