#!/bin/bash



dateLastHour=$(date +"%a %b %d %H:" -d '1 hour ago')

dateNow=$(date +"%a %b %d %H:")

utmpdump /var/log/wtmp* | awk "/$dateLastHour/,/$dateNow/" > utmpdumpResults.txt


Type of record (ut_type)
PID of login process (ut_pid)
Terminal name suffix, or inittab(5) ID (ut_id)
Username (ut_user)
Device name or tty - "/dev/" (ut_line)
Hostname for remote login, or kernel version for run-level messages (ut_host)
Internet address of remote host (ut_addr_v6)
Time entry was made (ut_time or actually ut_tv.tv_sec)



##### building bash for converting to json:
#!/bin/bash

# define example/test data to work with
utmpResults="[7] [08579] [ts/0] [egecko] [pts/0       ] [10.0.2.6            ] [1.1.1.1       ] [Fri Nov 04 23:40:29 2022 EDT]
[8] [08579] [    ] [        ] [pts/0       ] [                    ] [0.0.0.0        ] [Fri Nov 04 23:55:16 2022 EDT]
[2] [00000] [~~  ] [reboot  ] [~           ] [3.10.0-1160.80.1.el7.x86_64] [0.0.0.0        ] [Sat Dec 03 12:28:05 2022 EST]
[5] [00811] [tty1] [        ] [tty1        ] [                    ] [0.0.0.0        ] [Sat Dec 03 12:28:12 2022 EST]
[6] [00811] [tty1] [LOGIN   ] [tty1        ] [                    ] [0.0.0.0        ] [Sat Dec 03 12:28:12 2022 EST]
[1] [00051] [~~  ] [runlevel] [~           ] [3.10.0-1160.80.1.el7.x86_64] [0.0.0.0        ] [Sat Dec 03 12:28:58 2022 EST]
[7] [02118] [ts/0] [egecko] [pts/0       ] [1.1.1.1            ] [1.1.1.1       ] [Sat Dec 03 12:51:22 2022 EST]"

# remove any spaces longer than 1 character, keep all one character spaces
echo "$utmpResults" | sed 's/  */ /g'

# remove opening brackets
echo "$utmpResults" | sed 's/[[]//g'

echo "utmpResults" | cut -d "]"

for each line in results...


jq -R -c '
  select(length > 0) |                           # remove empty lines
  [match("\\[(.*?)\\]"; "g").captures[].string   # find content within square brackets
   | sub("^\\s+";"") | sub("\\s+$";"")]          # trim content
  | {                                            # convert to json object
      "ut_type"   : .[0],
      "ut_pid"   : .[1],
      "ut_id": .[2],
      "ut_user" : .[3],
      "ut_line": .[4],
      "ut_host"      : .[5],
      "ut_host_wan"      : .[6],
      "ut_time": .[7],
    }' utmpdumpResults.txt





