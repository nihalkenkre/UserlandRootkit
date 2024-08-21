# Userland Rootkit

A command line tool to hide process and registry keys from windows tools.

The dropper module is the CLI and the implant is the [sexe](https://medium.com/@nihal.kenkre/sexe-small-exe-e2f8b9acc805) file that is implanted into the target application.

The target applications are Process Hacker and Regedit to hide processes and keys respectively.

## Rootkit
Enter the rootkit
```
C:\> dropper.exe \ dropper.py
```

Exit the rootkit

```
Rootkit> exit
```

## Implant

Insert the implant into the target application (ProcessHacker)

```
Rootkit> insert implant ph
```

Remove the implant from the target application (ProcessHacker)

```
Rootkit> remove implant ph
```

## Processes

Hide a process from the ProcessHacker view

```
Rootkit> hide process malware.exe
```

Unhide a process from the ProcessHacker view

```
Rootkit> show process malware.exe
```

## Keys

### TODO
This functionality is not yet implemented.