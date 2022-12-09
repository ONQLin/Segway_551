fpath_set=`find /filespace/j/jlin445/ece551/demo/Segway_551/rtl_src/ -name "*.sv"`
fpath_set=$fpath_set" "`find /filespace/j/jlin445/ece551/demo/Segway_551/testbench -name "*.sv"`
fpath_set=$fpath_set" ""/filespace/j/jlin445/ece551/demo/Segway_551/testbench/define.svh"
echo "#for .do script 's filelist" > "./test.do"
for item in $fpath_set
do
      echo "vlog $item" >> "./test.do"
done
