//gcc -O2 -o pb pb.c -D_GNU_SOURCE && ./pb 10M /tmp/in /tmp/out   

#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

#define CHUNK_SIZE 4096

int main(int argc, char *argv[]) {
	int fd_in=STDIN_FILENO;
	int fd_out=STDOUT_FILENO;
	unsigned int buffer_size = 0;
	if (argc <= 1 || argc > 4) {
		printf("Usage: %s <size> [<in> [<out>]]\n\nBuffered copy from pipe to pipe/file\nUsing stdin and stdout if no files are specified.", argv[0]);
		exit(EXIT_FAILURE);
	}
	// Buffer Size
	else if (argc >= 2){
		char * end = "!";
		buffer_size = strtoul(argv[1], &end, 10);
		switch (*end){
			case 'm':
			case 'M':
				buffer_size *= 1024;
				// nobreak
			case 'k':
			case 'K':
				buffer_size *= 1024;
				// nobreak
			case 'b':
			case 'B':
			case '\0':
				break;
			default:
				fprintf(stderr, "Error parsing buffer size argument\n");
				exit(EXIT_FAILURE);
		}
		// In file (create if not exist, must be a pipe)
		if (argc >= 3){
			struct stat stat_in;
			if (stat(argv[2], &stat_in) == -1){
				if (mkfifo(argv[2], 0666) != 0) {
					perror("Cannot create in-pipe");
					exit(EXIT_FAILURE);
				}
			} else if ((stat_in.st_mode & S_IFMT) != S_IFIFO){
				fprintf(stderr, "Error in-file must be a pipe\n");
				exit(EXIT_FAILURE);
			}
			if ((fd_in = open(argv[2], O_RDONLY)) == -1){
				perror("Cannot open in-pipe");
				exit(EXIT_FAILURE);
			}

			// Out file (create if not exist)
			if (argc == 4){
				struct stat stat_out;
				if (stat(argv[3], &stat_out) == -1){
					if (mkfifo(argv[3], 0666) != 0) {
						perror("Cannot create out-pipe");
						exit(EXIT_FAILURE);
					}
				} else if ((stat_out.st_mode & S_IFMT) == S_IFDIR){
					fprintf(stderr, "Error out-file must not be a directory\n");
					exit(EXIT_FAILURE);
				}
				if ((fd_out = open(argv[3], O_WRONLY)) == -1){
					perror("Cannot open out-file");
					exit(EXIT_FAILURE);
				}
			}

			// Pipe size
			if (fcntl(fd_in, F_SETPIPE_SZ, buffer_size) == -1){
				switch(errno){
					case EPERM:
						fprintf(stderr, "Error buffer size of %u exceeds allowed maximum (defined in /proc/sys/fs/pipe-max-size). Change value or run as privileged process (with CAP_SYS_RESOURCE)\n", buffer_size);
						break;
					case EBUSY:
						fprintf(stderr, "Error buffer size of %u is below the minimum pipe capacity\n", buffer_size);
						break;
					default:
						perror("Error not able to set the pipe size");
				}
				exit(EXIT_FAILURE);
			}
		} 
	
		// Splice data
		ssize_t splice_data = 0;
		while ((splice_data = splice(fd_in, NULL, fd_out, NULL, CHUNK_SIZE, SPLICE_F_MOVE)) > 0);
		if (splice_data < 0){
			perror("Error splicing data failed.");
			exit(EXIT_FAILURE);
		}
	}
	return 0;
}

