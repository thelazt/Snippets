#ifndef _TSC_H_
#define _TSC_H_

#include <stdint.h>

/**
 * Read the value of the time stamp counter
 * @return cycles of the cpu (if supported)
 */
static inline uint64_t rdtsc() {
	uint32_t low, high;
	__asm__ __volatile__ ("rdtscp" : "=a" (low), "=d" (high) :: );
	return ((uint64_t)(high) << 32) | low;
}

/**
 * Read the value of the time stamp counter (prevent out-of-order-execution)
 * @return cycles of the cpu (if supported)
 */
static inline uint64_t rdtscp() {
	uint32_t low, high, cpuid;
	__asm__ __volatile__ ("rdtscp" : "=a" (low), "=d" (high), "=c" (cpuid) :: );
	return ((uint64_t)(high) << 32) | low;
}

/**
 * Read the value of the time stamp counter (prevent out-of-order-execution)
 * @return cycles of the cpu (if supported)
 */
static inline uint64_t rdtscp_info(uint32_t *core, uint32_t *physical) {
	uint32_t low, high, cpuid;
	__asm__ __volatile__ ("rdtscp" : "=a" (low), "=d" (high), "=c" (cpuid) :: );
	
	*physical = (cpuid & 0xfff000)>>12;
	*core = cpuid & 0xfff;

	return ((uint64_t)(high) << 32) | low;
}


uint64_t tsc2ns(uint64_t);
uint64_t ns2tsc(uint64_t);

#endif
