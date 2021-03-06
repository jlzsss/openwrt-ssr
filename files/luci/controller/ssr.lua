-- Copyright (C) 2017 yushi studio <ywb94@qq.com>
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.ssr", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ssr") then
		return
	end

         if nixio.fs.access("/usr/bin/ssr-redir") 
         then
         entry({"admin", "services", "ssr"},alias("admin", "services", "ssr", "client"),_("ssr"), 10).dependent = true
         entry({"admin", "services", "ssr", "client"},arcombine(cbi("ssr/client"), cbi("ssr/client-config")),_("SSR Client"), 10).leaf = true
         elseif nixio.fs.access("/usr/bin/ssr-server") 
         then 
         entry({"admin", "services", "ssr"},alias("admin", "services", "ssr", "server"),_("ssr"), 10).dependent = true
         else
          return
         end  
	

	if nixio.fs.access("/usr/bin/ssr-server") then
	entry({"admin", "services", "ssr", "server"},arcombine(cbi("ssr/server"), cbi("ssr/server-config")),_("SSR Server"), 20).leaf = true
	end
		

	entry({"admin", "services", "ssr", "status"},cbi("ssr/status"),_("Status"), 30).leaf = true
	entry({"admin", "services", "ssr", "check"}, call("check_status"))
	entry({"admin", "services", "ssr", "refresh"}, call("refresh_data"))
	entry({"admin", "services", "ssr", "checkport"}, call("check_port"))
	
end

function check_status()
local set ="/usr/bin/ssrr-check www." .. luci.http.formvalue("set") .. ".com 80 3 1"
sret=luci.sys.call(set)
if sret== 0 then
 retstring ="0"
else
 retstring ="1"
end	
luci.http.prepare_content("application/json")
luci.http.write_json({ ret=retstring })
end

function refresh_data()
local set =luci.http.formvalue("set")
local icount =0

if set == "gfw_data" then
 if nixio.fs.access("/usr/bin/wget-ssl") then
  refresh_cmd="wget-ssl --no-check-certificate https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt -O /tmp/gfw.b64"
 else
  refresh_cmd="wget -O /tmp/gfw.b64 http://iytc.net/tools/list.b64"
 end
 sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
 if sret== 0 then
  luci.sys.call("/usr/bin/ssrr-gfw")
  icount = luci.sys.exec("cat /tmp/gfwnew.txt | wc -l")
  if tonumber(icount)>1000 then
   oldcount=luci.sys.exec("cat /etc/dnsmasq.ssr/gfwlist.conf | wc -l")
   if tonumber(icount) ~= tonumber(oldcount) then
    luci.sys.exec("cp -f /tmp/gfwnew.txt /etc/dnsmasq.ssr/gfwlist.conf")
    retstring=tostring(math.ceil(tonumber(icount)/2))
   else
    retstring ="0"
   end
  else
   retstring ="-1"  
  end
  luci.sys.exec("rm -f /tmp/gfwnew.txt ")
 else
  retstring ="-1"
 end
elseif set == "ip_data" then
 refresh_cmd="wget -O- 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'  2>/dev/null| awk -F\\| '/CN\\|ipv4/ { printf(\"%s/%d\\n\", $4, 32-log($5)/log(2)) }' > /tmp/chinassr.txt"
 sret=luci.sys.call(refresh_cmd)
 icount = luci.sys.exec("cat /tmp/chinassr.txt | wc -l")
 if  sret== 0 and tonumber(icount)>1000 then
  oldcount=luci.sys.exec("cat /etc/chinassr.txt | wc -l")
  if tonumber(icount) ~= tonumber(oldcount) then
   luci.sys.exec("cp -f /tmp/chinassr.txt /etc/chinassr.txt")
   retstring=tostring(tonumber(icount))
  else
   retstring ="0"
  end

 else
  retstring ="-1"
 end
 luci.sys.exec("rm -f /tmp/chinassr.txt ")
else
  if nixio.fs.access("/usr/bin/wget-ssl") then
  refresh_cmd="wget --no-check-certificate -O - https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt | grep ^\\|\\|[^\\*]*\\^$ | sed -e 's:||:address\\=\\/:' -e 's:\\^:/127\\.0\\.0\\.1:' > /tmp/ad.conf"
 else
  refresh_cmd="wget -O /tmp/ad.conf http://iytc.net/tools/ad.conf"
 end
 sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
 if sret== 0 then
  icount = luci.sys.exec("cat /tmp/ad.conf | wc -l")
  if tonumber(icount)>1000 then
   if nixio.fs.access("/etc/dnsmasq.ssr/ad.conf") then
    oldcount=luci.sys.exec("cat /etc/dnsmasq.ssr/ad.conf | wc -l")
   else
    oldcount=0
   end
   
   if tonumber(icount) ~= tonumber(oldcount) then
    luci.sys.exec("cp -f /tmp/ad.conf /etc/dnsmasq.ssr/ad.conf")
    retstring=tostring(math.ceil(tonumber(icount)))
    if oldcount==0 then
     luci.sys.call("/etc/init.d/dnsmasq restart")
    end
   else
    retstring ="0"
   end
  else
   retstring ="-1"  
  end
  luci.sys.exec("rm -f /tmp/ad.conf ")
 else
  retstring ="-1"
 end
end	
luci.http.prepare_content("application/json")
luci.http.write_json({ ret=retstring ,retcount=icount})
end


function check_port()
local set=""
local retstring="<br /><br />"
local s
local server_name = ""
local ssr = "ssr"
local uci = luci.model.uci.cursor()
local iret=1

uci:foreach(ssr, "servers", function(s)

	if s.alias then
		server_name=s.alias
	elseif s.server and s.server_port then
		server_name= "%s:%s" %{s.server, s.server_port}
	end
	iret=luci.sys.call(" ipset add ss_spec_wan_ac " .. s.server .. " 2>/dev/null")
	socket = nixio.socket("inet", "stream")
	socket:setopt("socket", "rcvtimeo", 3)
	socket:setopt("socket", "sndtimeo", 3)
	ret=socket:connect(s.server,s.server_port)
	if  tostring(ret) == "true" then
	socket:close()
	retstring =retstring .. "<font color='green'>[" .. server_name .. "] OK.</font><br />"
	else
	retstring =retstring .. "<font color='red'>[" .. server_name .. "] Error.</font><br />"
	end	
	if  iret== 0 then
	luci.sys.call(" ipset del ss_spec_wan_ac " .. s.server)
	end
end)

luci.http.prepare_content("application/json")
luci.http.write_json({ ret=retstring })
end
