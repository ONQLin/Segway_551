fpath_set=`find /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/ -name "*.sv"`
fpath_set=$fpath_set" "`find /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/ -name "*.sv"`
fpath_set=$fpath_set" ""/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh"
echo "#for .do script 's filelist" > "./test.do"
for item in $fpath_set
do
      echo "vlog $item" >> "./test.do"
done
