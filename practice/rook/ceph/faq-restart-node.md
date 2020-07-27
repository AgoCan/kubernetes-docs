

报错信息

```
**[terminal]
[root@k8s01 ~]# kubectl logs rook-ceph-osd-0-c85786fcd-bffzk/activate-osd -n rook-ceph
error: the server doesn't have a resource type "rook-ceph-osd-0-c85786fcd-bffzk"
[root@k8s01 ~]# kubectl logs rook-ceph-osd-0-c85786fcd-bffzk -n rook-ceph
Error from server (BadRequest): container "osd" in pod "rook-ceph-osd-0-c85786fcd-bffzk" is waiting to start: PodInitializing
[root@k8s01 ~]# kubectl logs rook-ceph-osd-0-c85786fcd-bffzk -n rook-ceph -c activate-osd
+ OSD_ID=0
+ OSD_UUID=fcff6a44-d822-4b63-8e37-850f3d42745a
+ OSD_STORE_FLAG=--bluestore
++ mktemp -d
+ TMP_DIR=/tmp/tmp.39C1Zcup4b
+ OSD_DATA_DIR=/var/lib/ceph/osd/ceph-0
+ ceph-volume lvm activate --no-systemd --bluestore 0 fcff6a44-d822-4b63-8e37-850f3d42745a
Running command: /bin/chown -R ceph:ceph /var/lib/ceph/osd/ceph-0
Running command: /bin/ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev /dev/ceph-f28a112a-41f3-4ead-b44c-4b864a35b100/osd-data-5ec055ea-9c01-43d3-a5af-1e8c1d4432a0 --path /var/lib/ceph/osd/ceph-0 --no-mon-config
 stderr: failed to read label for /dev/ceph-f28a112a-41f3-4ead-b44c-4b864a35b100/osd-data-5ec055ea-9c01-43d3-a5af-1e8c1d4432a0: (2) No such file or directory
2019-12-30 08:31:35.986 7fc852e9dc00 -1 bluestore(/dev/ceph-f28a112a-41f3-4ead-b44c-4b864a35b100/osd-data-5ec055ea-9c01-43d3-a5af-1e8c1d4432a0) _read_bdev_label failed to open /dev/ceph-f28a112a-41f3-4ead-b44c-4b864a35b100/osd-data-5ec055ea-9c01-43d3-a5af-1e8c1d4432a0: (2) No such file or directory
Traceback (most recent call last):
  File "/usr/sbin/ceph-volume", line 9, in <module>
    load_entry_point('ceph-volume==1.0.0', 'console_scripts', 'ceph-volume')()
  File "/usr/lib/python2.7/site-packages/ceph_volume/main.py", line 38, in __init__
    self.main(self.argv)
  File "/usr/lib/python2.7/site-packages/ceph_volume/decorators.py", line 59, in newfunc
    return f(*a, **kw)
  File "/usr/lib/python2.7/site-packages/ceph_volume/main.py", line 149, in main
    terminal.dispatch(self.mapper, subcommand_args)
  File "/usr/lib/python2.7/site-packages/ceph_volume/terminal.py", line 194, in dispatch
    instance.main()
  File "/usr/lib/python2.7/site-packages/ceph_volume/devices/lvm/main.py", line 40, in main
    terminal.dispatch(self.mapper, self.argv)
  File "/usr/lib/python2.7/site-packages/ceph_volume/terminal.py", line 194, in dispatch
    instance.main()
  File "/usr/lib/python2.7/site-packages/ceph_volume/devices/lvm/activate.py", line 341, in main
    self.activate(args)
  File "/usr/lib/python2.7/site-packages/ceph_volume/decorators.py", line 16, in is_root
    return func(*a, **kw)
  File "/usr/lib/python2.7/site-packages/ceph_volume/devices/lvm/activate.py", line 265, in activate
    activate_bluestore(lvs, no_systemd=args.no_systemd)
  File "/usr/lib/python2.7/site-packages/ceph_volume/devices/lvm/activate.py", line 172, in activate_bluestore
    process.run(prime_command)
  File "/usr/lib/python2.7/site-packages/ceph_volume/process.py", line 153, in run
    raise RuntimeError(msg)
RuntimeError: command returned non-zero exit status: 1
```

解决：
