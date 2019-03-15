#include <stdio.h>
#include <inttypes.h>

#include "tsc.h"

#ifndef RDTSCP
#error RDTSCP not available
#endif
#ifndef CPU_MODEL
#error CPU_MODEL not available
#endif
#ifndef MSR_FREQUENCY
#error MSR_FREQUENCY not available
#endif

const uint64_t timestampCyclesPerSecond =
#if ( CPU_MODEL ) == 0x1a || ( CPU_MODEL ) == 0x1e || ( CPU_MODEL ) == 0x1f || ( CPU_MODEL ) == 0x2e || ( CPU_MODEL ) == 0x25 || ( CPU_MODEL ) == 0x2c || ( CPU_MODEL ) == 0x2f
		133333333ULL
#else
		100000000ULL 
#endif
	* (((MSR_FREQUENCY) & 0xff00) >> 8);

/**
 * Convert TSC cycles to nanoseconds
 * Requires to retrieve the TSC frequency (in KHz)
 * To avoid superuser privileges, these are read at compile time (since we use -march=native, you should already never transfer binaries).
 * Only one CPU model per system supported to determine base clock (different CPUs in one system might lead to incorrect values). Only recent models are supported.
 * @warning slightly incorrect due to rounding issues (about 0.5%)
 * @return nanosecond representation of cycles
 **/
uint64_t tsc2ns(uint64_t cycles) {
	return cycles *
#if	( CPU_MODEL ) == 0x1a || ( CPU_MODEL ) == 0x1e || ( CPU_MODEL ) == 0x1f || ( CPU_MODEL ) == 0x2e || ( CPU_MODEL ) == 0x25 || ( CPU_MODEL ) == 0x2c || ( CPU_MODEL ) == 0x2f  // nehalem or westmere
		100000ULL / 13333ULL
		
#elif ( CPU_MODEL ) == 0x2a || ( CPU_MODEL ) == 0x2d || ( CPU_MODEL ) == 0x3a || ( CPU_MODEL ) == 0x3e || ( CPU_MODEL ) == 0x3c || ( CPU_MODEL ) == 0x3f || ( CPU_MODEL ) == 0x45 || ( CPU_MODEL ) == 0x46 || ( CPU_MODEL ) == 0x3d || ( CPU_MODEL ) == 0x47 || ( CPU_MODEL ) == 0x4f || ( CPU_MODEL ) ==  0x56 || ( CPU_MODEL ) == 0x4e || ( CPU_MODEL ) == 0x5e || ( CPU_MODEL ) == 0x57  // sandy bridge, ivy bridge, haswell, broadwell, skylake or xeon phi
		10ULL
#else  // unknown cpu, warn
#warning Unknown CPU Model, guessing base clock (might be wrong)
		10ULL
#endif
		// Non-turbo frequency read from MSR (sudo rdmsr 0xCE)
		/ (((MSR_FREQUENCY) & 0xff00) >> 8);
}


/**
 * Convert nanoseconds to TSC cycles
 * Requires to retrieve the TSC frequency (in KHz)
 * To avoid superuser privileges, these are read at compile time (since we use -march=native, you should already never transfer binaries).
 * Only one CPU model per system supported to determine base clock (different CPUs in one system might lead to incorrect values). Only recent models are supported.
 * @warning only for small values (< 100 sec); slightly incorrect due to rounding issues (about 0.5%)
 * @return cycles representation of nanosecond values
 **/
uint64_t ns2tsc(uint64_t ns) {
	// Non-turbo frequency read from MSR (sudo rdmsr 0xCE)
	return ns * (((MSR_FREQUENCY) & 0xff00) >> 8)
		// nehalem or westmere
#if ( CPU_MODEL ) == 0x1a || ( CPU_MODEL ) == 0x1e || ( CPU_MODEL ) == 0x1f || ( CPU_MODEL ) == 0x2e || ( CPU_MODEL ) == 0x25 || ( CPU_MODEL ) == 0x2c || ( CPU_MODEL ) == 0x2f
		* 13333ULL / 100000ULL
#else
		/ 10ULL
#endif
		;
}
