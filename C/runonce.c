#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>

#define RUNONCE(X) 																	\
{																					\
	void __attribute__ ((noinline)) runonce (void){									\
		static long pagesize = -2;													\
		if (pagesize == -2){														\
			pagesize = sysconf(_SC_PAGE_SIZE);										\
			char * call = __builtin_extract_return_addr(__builtin_return_address(0))-5;	\
		    if (!mprotect((void*)( call - ((unsigned long long) call % pagesize)),	pagesize, PROT_READ|PROT_WRITE|PROT_EXEC)){	\
				call[0] = 0x0f;														\
				call[1] = 0x1f;														\
				call[2] = 0x44;														\
				call[3] = call[4] = 0x00;											\
				{ X ; }																\
			}																		\
		}																			\
	}																				\
	runonce();																		\
}

int main(void){
	while (1){
		printf("Hello");
		RUNONCE({
			printf(" world");
		})
		putchar('\n');
		sleep(1);
    }
    return 0;
}

