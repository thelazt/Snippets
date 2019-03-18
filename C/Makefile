# enable time stamp counter if supported by cpu
ifeq ($(shell cat /proc/cpuinfo | grep "rdtscp" | grep "constant_tsc" | grep "nonstop_tsc" | wc -l ),$(shell nproc --all ))
CFLAGS += -std=c11 -D_GNU_SOURCE -DRDTSCP -DCPU_MODEL=$(shell cat /proc/cpuinfo | egrep "^model\s+: [0-9]+$$" | sed -e "s/^.*: //" | uniq ) -DMSR_FREQUENCY=0x$(shell grep "ID=ubuntu" /etc/os-release > /dev/null && lsmod | grep msr >/dev/null || sudo modprobe msr ; sudo rdmsr 0xCE)ULL
endif

tsc-test: tsc.c tsc.h tsc_test.c
	$(CC) $(CFLAGS) $^ -o $@
