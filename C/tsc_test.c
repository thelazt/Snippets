#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>
#include <time.h>
#include <locale.h>


#include "tsc.h"

static inline unsigned long long clockts(clockid_t c) {
	struct timespec tp;
	clock_gettime(c, &tp);
	return (tp.tv_sec * 1000000000) + (tp.tv_nsec);
}

static inline void sleep(){
	for (volatile uint32_t s = 0; s < 1 << 23 ; s++);
}

static void clockbench(clockid_t c, const char * name){
	uint64_t a,b;
	a = clockts(c);
	sleep();
	b = clockts(c);
	struct timespec tp;
	clock_getres(c, &tp);
	printf("%20s: %'" PRIu64 "ns (Resolution %'" PRIu64 "ns)\n", name, b - a, (tp.tv_sec * 1000000000) + (tp.tv_nsec));
}



int main(){
	setlocale(LC_NUMERIC, "");
	puts("Sleep using");

	sleep(); // Warmup

	uint64_t a,b;

	clockbench(CLOCK_REALTIME, "REALTIME");
	clockbench(CLOCK_REALTIME_COARSE, "REALTIME (COARSE)");
	clockbench(CLOCK_MONOTONIC, "MONOTONIC");
	clockbench(CLOCK_PROCESS_CPUTIME_ID, "PROCESS CPUTIME ID");
	clockbench(CLOCK_THREAD_CPUTIME_ID, "THREAD CPUTIME ID");

	a = rdtsc();
	sleep();
	b = rdtsc();
	printf("               RDTSC: %'" PRIu64 "ns (Cycles: %'" PRIu64 ")\n", tsc2ns(b - a), b - a);

	a = rdtscp();
	sleep();
	b = rdtscp();
	printf("              RDTSCP: %'" PRIu64 "ns (Cycles: %'" PRIu64 ")\n", tsc2ns(b - a), b - a);

	uint32_t c,d;
	a = rdtscp_info(&c, &d);
	sleep();
	b = rdtscp_info(&c, &d);
	printf("       RDTSCP (INFO): %'" PRIu64 "ns (Cycles: %'" PRIu64 ", core: %" PRIu32 ", physical: %" PRIu32 ")\n", tsc2ns(b - a), b - a, c, d);
	return 0;
}
