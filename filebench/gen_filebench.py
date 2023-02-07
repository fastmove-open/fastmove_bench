#!/usr/bin/env python3
import argparse
import sys

FILESERVER_TEMPLATE="""
set $dir=%s
set $nfiles=%d
set $meandirwidth=%d
set $filesize=cvar(type=cvar-gamma,parameters=mean:8192;gamma:1.5,round=4096)
set $nthreads=%d
set $iosize=1m
set $meanappendsizea=cvar(type=cvar-gamma,parameters=mean:655360;gamma:1.5,min=4096,round=4096)
set $meanappendsizeb=cvar(type=cvar-gamma,parameters=mean:16384;gamma:1.5,min=4096,round=4096)
set $runtime=%d

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=80

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=20m,instances=$nthreads
  {
  flowop createfile name=createfile1,filesetname=bigfileset,fd=1
  flowop writewholefile name=wrtfile1,srcfd=1,fd=1,iosize=$iosize
  flowop closefile name=closefile1,fd=1
  flowop openfile name=openfile1,filesetname=bigfileset,fd=1
  flowop appendfile name=appendfilerand1,iosize=$meanappendsizeb,fd=1
  flowop closefile name=closefile2,fd=1
  flowop openfile name=openfile2,filesetname=bigfileset,fd=1
  flowop readwholefile name=readfile1,fd=1,iosize=$iosize
  flowop closefile name=closefile3,fd=1
  flowop openfile name=openfile1,filesetname=bigfileset,fd=1
  flowop appendfile name=appendfilerand2,iosize=$meanappendsizea,fd=1
  flowop closefile name=closefile2,fd=1
  flowop openfile name=openfile2,filesetname=bigfileset,fd=1
  flowop readwholefile name=readfile1,fd=1,iosize=$iosize
  flowop closefile name=closefile3,fd=1
  flowop deletefile name=deletefile1,filesetname=bigfileset
  flowop statfile name=statfile1,filesetname=bigfileset
  }
}

enable lathist
run $runtime
"""

VARMAIL_TEMPLATE="""
set $dir=%s
set $nfiles=%d
set $meandirwidth=%d
set $filesize=cvar(type=cvar-gamma,parameters=mean:16384;gamma:1.5)
set $nthreads=%d
set $iosize=%s
set $meanappendsize=%s
set $runtime=%d

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=80

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop deletefile name=deletefile1,filesetname=bigfileset
    flowop createfile name=createfile2,filesetname=bigfileset,fd=1
    flowop appendfilerand name=appendfilerand2,iosize=$meanappendsize,fd=1
    flowop fsync name=fsyncfile2,fd=1
    flowop closefile name=closefile2,fd=1
    flowop openfile name=openfile3,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile3,fd=1,iosize=$iosize
    flowop appendfilerand name=appendfilerand3,iosize=$meanappendsize,fd=1
    flowop fsync name=fsyncfile3,fd=1
    flowop closefile name=closefile3,fd=1
    flowop openfile name=openfile4,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile4,fd=1,iosize=$iosize
    flowop closefile name=closefile4,fd=1
  }
}

enable lathist
run $runtime
"""

WEBPROXY_TEMPLATE="""
set $dir=%s
set $nfiles=%d
set $meandirwidth=%d
set $meanfilesize=%s
set $nthreads=%d
set $meaniosize=%s
set $iosize=%s
set $runtime=%d

define fileset name=bigfileset,path=$dir,size=$meanfilesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=80

define process name=proxycache,instances=1
{
  thread name=proxycache,memsize=10m,instances=$nthreads
  {
    flowop deletefile name=deletefile1,filesetname=bigfileset
    flowop createfile name=createfile1,filesetname=bigfileset,fd=1
    flowop appendfilerand name=appendfilerand1,iosize=$meaniosize,fd=1
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile2,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile2,fd=1,iosize=$iosize
    flowop closefile name=closefile2,fd=1
    flowop openfile name=openfile3,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile3,fd=1,iosize=$iosize
    flowop closefile name=closefile3,fd=1
    flowop openfile name=openfile4,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile4,fd=1,iosize=$iosize
    flowop closefile name=closefile4,fd=1
    flowop openfile name=openfile5,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile5,fd=1,iosize=$iosize
    flowop closefile name=closefile5,fd=1
    flowop openfile name=openfile6,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile6,fd=1,iosize=$iosize
    flowop closefile name=closefile6,fd=1
    flowop opslimit name=limit
  }
}

enable lathist
run $runtime
"""

WEBSERVER_TEMPLATE="""
set $dir=%s
set $nfiles=%d
set $meandirwidth=%d
set $filesize=cvar(type=cvar-gamma,parameters=mean:16384;gamma:1.5)
set $nthreads=%d
set $iosize=%s
set $meanappendsize=%s
set $runtime=%d

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=100,readonly
define fileset name=logfiles,path=$dir,size=$filesize,entries=1,dirwidth=$meandirwidth,prealloc

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop openfile name=openfile1,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile1,fd=1,iosize=$iosize
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile2,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile2,fd=1,iosize=$iosize
    flowop closefile name=closefile2,fd=1
    flowop openfile name=openfile3,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile3,fd=1,iosize=$iosize
    flowop closefile name=closefile3,fd=1
    flowop openfile name=openfile4,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile4,fd=1,iosize=$iosize
    flowop closefile name=closefile4,fd=1
    flowop openfile name=openfile5,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile5,fd=1,iosize=$iosize
    flowop closefile name=closefile5,fd=1
    flowop openfile name=openfile6,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile6,fd=1,iosize=$iosize
    flowop closefile name=closefile6,fd=1
    flowop openfile name=openfile7,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile7,fd=1,iosize=$iosize
    flowop closefile name=closefile7,fd=1
    flowop openfile name=openfile8,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile8,fd=1,iosize=$iosize
    flowop closefile name=closefile8,fd=1
    flowop openfile name=openfile9,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile9,fd=1,iosize=$iosize
    flowop closefile name=closefile9,fd=1
    flowop openfile name=openfile10,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile10,fd=1,iosize=$iosize
    flowop closefile name=closefile10,fd=1
    flowop appendfilerand name=appendlog,filesetname=logfiles,iosize=$meanappendsize,fd=2
  }
}

enable lathist
run $runtime
"""

VIDEOSERVER_TEMPLATE="""
set $dir=%s
set $eventrate=96
set $filesize=10g
set $nthreads=%d
set $numactivevids=32
set $numpassivevids=194
set $reuseit=false
set $readiosize=256k
set $writeiosize=1m

set $passvidsname=passivevids
set $actvidsname=activevids

set $repintval=10

eventgen rate=$eventrate

define fileset name=$actvidsname,path=$dir,size=$filesize,entries=$numactivevids,dirwidth=4,prealloc,paralloc,reuse=$reuseit
define fileset name=$passvidsname,path=$dir,size=$filesize,entries=$numpassivevids,dirwidth=20,prealloc=50,paralloc,reuse=$reuseit

define process name=vidwriter,instances=1
{
  thread name=vidwriter,memsize=10m,instances=1
  {
    flowop deletefile name=vidremover,filesetname=$passvidsname
    flowop createfile name=wrtopen,filesetname=$passvidsname,fd=1
    flowop writewholefile name=newvid,iosize=$writeiosize,fd=1,srcfd=1
    flowop closefile name=wrtclose, fd=1
    flowop delay name=replaceinterval, value=$repintval
  }
}

define process name=vidreaders,instances=1
{
  thread name=vidreaders,memsize=10m,instances=$nthreads
  {
    flowop read name=vidreader,filesetname=$actvidsname,iosize=$readiosize
    flowop bwlimit name=serverlimit, target=vidreader
  }
}

enable lathist
run $runtime
"""

NEWWORKLOAD2_TEMPLATE="""
set $dir=%s
set $nfiles=%d
set $meandirwidth=%d
set $filesize=64m
set $nthreads=%d
set $iosize=1m
set $rwsize=16k
set $runtime=%d

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=100

define process name=newworkload1,instances=1
{
  thread name=bulkwriterthread,memsize=10m,instances=$nthreads
  {
    flowop openfile name=createfile1,filesetname=bigfileset,fd=1
    flowop writewholefile name=wrtfile1,srcfd=1,fd=1,iosize=$iosize
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=bigfileset,fd=1
    flowop read name=readfilerand1,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand2,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand3,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand4,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand5,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand6,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand7,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand8,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand9,iosize=$rwsize,fd=1,random
    flowop read name=readfilerand10,iosize=$rwsize,fd=1,random
    flowop closefile name=closefile1,fd=1
  }
}

enable lathist
run $runtime
"""



def add_common_args(parser):
    parser.add_argument('-d', '--directory', metavar='PATH', type=str, dest='dir',
                    help='directory', required=True)
    parser.add_argument('-r', '--runtime', metavar='SECONDS', type=int, dest='runtime',
                    help='runtime(seconds)', default=60)
    parser.add_argument('-n', '--nfiles', metavar='NUM', type=int, dest='nfiles',
                    help='number of files', required=True)
    parser.add_argument('-m', '--mean_dir_width', metavar='NUM', type=int, dest='meandirwidth',
                    help='mean directory width', required=True)
    parser.add_argument('-t', '--nthreads', metavar='NUM', type=int, dest='nthreads',
                    help='number of threads', required=True)
    parser.add_argument('-i', '--iosize', metavar='SIZE', type=str, dest='iosize',
                    help='iosize', default='1m')
    parser.add_argument('-o', '--output_file', metavar='PATH', type=str, dest='output',
                    help='output workload file', default='filebench_workload')

def dump_workload(workload, path):
    with open(path, 'w') as f:
        f.write(workload)

def gen_fileserver():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' fileserver', description='generate fileserver workload')
    add_common_args(parser)
    parser.add_argument('-a', '--mean_append_size', metavar='SIZE', type=str, dest='meanappendsize',
                    help='mean append size', default='16k')
    arg = parser.parse_args(sys.argv[2:])
    workload = FILESERVER_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.nthreads, arg.runtime)
    dump_workload(workload, arg.output)

def gen_varmail():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' varmail', description='generate varmail workload')
    add_common_args(parser)
    parser.add_argument('-a', '--mean_append_size', metavar='SIZE', type=str, dest='meanappendsize',
                    help='mean append size', default='16k')
    arg = parser.parse_args(sys.argv[2:])
    workload = VARMAIL_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.nthreads, arg.iosize, arg.meanappendsize, arg.runtime)
    dump_workload(workload, arg.output)

def gen_webproxy():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' webproxy', description='generate webproxy workload')
    add_common_args(parser)
    parser.add_argument('--mean_iosize', metavar='SIZE', type=str, dest='meaniosize',
                    help='mean io size', default='16k')
    parser.add_argument('--mean_filesize', metavar='SIZE', type=str, dest='meanfilesize',
                    help='mean file size', default='32k')
    arg = parser.parse_args(sys.argv[2:])
    workload = WEBPROXY_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.meanfilesize, arg.nthreads, arg.meaniosize, arg.iosize, arg.runtime)
    dump_workload(workload, arg.output)

def gen_webserver():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' webserver', description='generate webserver workload')
    add_common_args(parser)
    parser.add_argument('-a', '--mean_append_size', metavar='SIZE', type=str, dest='meanappendsize',
                    help='mean append size', default='8k')
    arg = parser.parse_args(sys.argv[2:])
    workload = WEBSERVER_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.nthreads, arg.iosize, arg.meanappendsize, arg.runtime)
    dump_workload(workload, arg.output)

def gen_newworkload1():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' newworkload1', description='generate newworkload1 workload')
    add_common_args(parser)
    parser.add_argument('-g', '--nthreads2', metavar='NUM', type=int, dest='nthreads2',
                    help='number of threads 2', required=True)
    parser.add_argument('-s', '--rwsize', metavar='SIZE', type=str, dest='rwsize',
                    help='rwsize', default='16k')
    arg = parser.parse_args(sys.argv[2:])
    workload = NEWWORKLOAD1_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.nthreads, arg.nthreads2, arg.iosize, arg.rwsize, arg.runtime)
    dump_workload(workload, arg.output)

def gen_newworkload2():
    parser = argparse.ArgumentParser(prog=sys.argv[0]+' newworkload1', description='generate newworkload1 workload')
    add_common_args(parser)
    arg = parser.parse_args(sys.argv[2:])
    workload = NEWWORKLOAD2_TEMPLATE % (arg.dir, arg.nfiles, arg.meandirwidth, arg.nthreads, arg.runtime)
    dump_workload(workload, arg.output)



if __name__ == "__main__":
    selector = argparse.ArgumentParser(description='utility to generate filebench workload')
    selector.add_argument('workload_type', choices=['fileserver', 'varmail', 'webproxy', 'webserver', 'newworkload1', 'newworkload2'],
                    help='choose workload type')
    arg = selector.parse_args(sys.argv[1:2])
    if arg.workload_type == 'fileserver':
        gen_fileserver()
    elif arg.workload_type == 'varmail':
        gen_varmail()
    elif arg.workload_type == 'webproxy':
        gen_webproxy()
    elif arg.workload_type == 'webserver':
        gen_webserver()
    elif arg.workload_type == 'videoserver':
        gen_newworkload1()
    elif arg.workload_type == 'newworkload2':
        gen_newworkload2()
