/**
 * Generating a pretty printed dump of variables (especially of structs) in C
 * without (manual / automatic) writing print functions for each struct.
 * by using GDB (therefore it is necessary to compile with debug information)
 *
 * Sample run:
 * 	$ gcc -g vardump.c && ./a.out
 *	[vardump.c:36 main] (struct foo) &a = {bar = 23, baz = {foz = 0 ''}}
 *	[vardump.c:38 main] (struct foo) b = {bar = 42, baz = {foz = 119 'w'}}
 *
 * Not fast, but simple :)
 *
 * Thanks to http://stackoverflow.com/questions/3311182/linux-c-easy-pretty-dump-printout-of-structs-like-in-gdb-from-source-co
 */
#include <stdio.h>
#include <stdlib.h>

extern const char *__progname;

#define varDump(TYPE, POINTER) { char *p; asprintf(&p, "tmpfile=$(mktemp) ; echo 'p (%s) *%p\n' > $tmpfile ; echo -e \"\e[2m[%s:%d %s] (%s) %s = $(echo 'where\ndetach' | gdb -batch --command=$tmpfile %s %d 2> /dev/null | tail -n 1 | sed -e 's/$[0-9]* = //')\e[0m\" ; rm $tmpfile", #TYPE, POINTER, __FILE__, __LINE__, __FUNCTION__, #TYPE, #POINTER, __progname, getpid() ); system(p); free(p); }

struct foo {
	int bar;
	struct {
		char foz;
	} baz;
};

main (){
	struct foo a = { .bar=23 };

	struct foo * b = (struct foo *)malloc(sizeof(struct foo));
	b->bar = 42;
	b->baz.foz='w';

	varDump(struct foo , &a);

	varDump(struct foo , b);
}
