#
# Copyright (C) 2017 OpenWrt-ssr
# Copyright (C) 2017 yushi studio <ywb94@qq.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openwrt-ssr
PKG_VERSION:=1.3.1
#PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/xmapst/shadowsocks-libev
PKG_SOURCE_VERSION:=11db1d5e48f539855ea1a66947eba9bb9bc82150

PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=xmapst <xmapst@gmil.com>

#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)

PKG_INSTALL:=1
PKG_FIXUP:=autoreconf
PKG_USE_MIPS16:=0
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/openwrt-ssr/Default
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=shadowsocksR-libev LuCI interface
	URL:=https://github.com/xmapst/openwrt-ssr
	VARIANT:=$(1)
	DEPENDS:=$(3)	
	PKGARCH:=all
endef


Package/luci-app-shadowsocksR = $(call Package/openwrt-ssr/Default,openssl,(OpenSSL),+libopenssl +libpthread +ipset +ip +iptables-mod-tproxy +libpcre +zlib)
Package/luci-app-shadowsocksR-Client = $(call Package/openwrt-ssr/Default,openssl,(OpenSSL),+libopenssl +libpthread +ipset +ip +iptables-mod-tproxy +libpcre +zlib)
Package/luci-app-shadowsocksR-Server = $(call Package/openwrt-ssr/Default,openssl,(OpenSSL),+libopenssl +libpthread +ipset +ip +iptables-mod-tproxy +libpcre +zlib)
Package/luci-app-shadowsocksR-GFW = $(call Package/openwrt-ssr/Default,openssl,(OpenSSL),+libopenssl +libpthread +ipset +ip +iptables-mod-tproxy +libpcre +zlib +dnsmasq-full +coreutils +coreutils-base64)

define Package/openwrt-ssr/description
	LuCI Support for $(1).
endef

Package/luci-app-shadowsocksR/description = $(call Package/openwrt-ssr/description,shadowsocksr-libev Client and Server)
Package/luci-app-shadowsocksR-Client/description = $(call Package/openwrt-ssr/description,shadowsocksr-libev Client)
Package/luci-app-shadowsocksR-Server/description = $(call Package/openwrt-ssr/description,shadowsocksr-libev Server)
Package/luci-app-shadowsocksR-GFW/description = $(call Package/openwrt-ssr/description,shadowsocksr-libev GFW)

define Package/openwrt-ssr/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Removing rc.d symlink for shadowsocksr"
     /etc/init.d/ssr disable
     /etc/init.d/ssr stop
    echo "Removing firewall rule for shadowsocksr"
	  uci -q batch <<-EOF >/dev/null
		delete firewall.ssr
		commit firewall
EOF
if [ "$(1)" = "GFW" ] ;then
sed -i '/conf-dir/d' /etc/dnsmasq.conf 
/etc/init.d/dnsmasq restart 
fi
fi
exit 0
endef

Package/luci-app-shadowsocksR/prerm = $(call Package/openwrt-ssr/prerm,ssr)
Package/luci-app-shadowsocksR-Client/prerm = $(call Package/openwrt-ssr/prerm,ssr)
Package/luci-app-shadowsocksR-GFW/prerm = $(call Package/openwrt-ssr/prerm,GFW)

define Package/luci-app-shadowsocksR-Server/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
 /etc/init.d/ssr disable
 /etc/init.d/ssr stop
fi 
exit 0

endef


define Package/openwrt-ssr/postinst
#!/bin/sh

if [ -z "$${IPKG_INSTROOT}" ]; then
	uci -q batch <<-EOF >/dev/null
		delete firewall.ssr
		set firewall.ssr=include
		set firewall.ssr.type=script
		set firewall.ssr.path=/var/etc/ssr.include
		set firewall.ssr.reload=0
		commit firewall
EOF
fi

if [ -z "$${IPKG_INSTROOT}" ]; then
	( . /etc/uci-defaults/luci-ssr ) && rm -f /etc/uci-defaults/luci-ssr
	chmod 755 /etc/init.d/ssr >/dev/null 2>&1
	/etc/init.d/ssr enable >/dev/null 2>&1
fi
exit 0
endef


Package/luci-app-shadowsocksR/postinst = $(call Package/openwrt-ssr/postinst,ssr)
Package/luci-app-shadowsocksR-Client/postinst = $(call Package/openwrt-ssr/postinst,ssr)
Package/luci-app-shadowsocksR-GFW/postinst = $(call Package/openwrt-ssr/postinst,GFW)

define Package/luci-app-shadowsocksR-Server/postinst
#!/bin/sh

if [ -z "$${IPKG_INSTROOT}" ]; then
	( . /etc/uci-defaults/luci-ssr ) && rm -f /etc/uci-defaults/luci-ssr
	chmod 755 /etc/init.d/ssr >/dev/null 2>&1
	/etc/init.d/ssr enable >/dev/null 2>&1
fi
exit 0
endef



CONFIGURE_ARGS += --disable-documentation --disable-ssp

define Package/openwrt-ssr/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/$(2).lua $(1)/usr/lib/lua/luci/controller/$(2).lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./files/luci/i18n/$(2).*.lmo $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/ssr
	$(INSTALL_DATA) ./files/luci/model/cbi/ssr/*.lua $(1)/usr/lib/lua/luci/model/cbi/ssr/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/ssr
	$(INSTALL_DATA) ./files/luci/view/ssr/*.htm $(1)/usr/lib/lua/luci/view/ssr/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/root/etc/uci-defaults/luci-$(2) $(1)/etc/uci-defaults/luci-$(2)
	$(INSTALL_DIR) $(1)/usr/bin
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-redir $(1)/usr/bin/ssr-redir
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-tunnel $(1)/usr/bin/ssr-tunnel
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-local $(1)/usr/bin/ssr-local	
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-server $(1)/usr/bin/ssr-server		
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-check $(1)/usr/bin/ssr-check
	$(INSTALL_BIN) ./files/ssr.rule $(1)/usr/bin/ssrr-rules
	$(INSTALL_BIN) ./files/ssr.monitor $(1)/usr/bin/ssrr-monitor
	$(INSTALL_BIN) ./files/ssr.switch $(1)/usr/bin/ssrr-switch
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/ssr.config $(1)/etc/config/ssr
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) ./files/china_ssr.txt $(1)/etc/china_ssr.txt	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ssr.init $(1)/etc/init.d/ssr
endef

Package/luci-app-shadowsocksR/install = $(call Package/openwrt-ssr/install,$(1),ssr)

define Package/luci-app-shadowsocksR-Client/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/ssr.lua $(1)/usr/lib/lua/luci/controller/ssr.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./files/luci/i18n/ssr.*.lmo $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/ssr
	$(INSTALL_DATA) ./files/luci/model/cbi/ssr/*.lua $(1)/usr/lib/lua/luci/model/cbi/ssr/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/ssr
	$(INSTALL_DATA) ./files/luci/view/ssr/*.htm $(1)/usr/lib/lua/luci/view/ssr/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/root/etc/uci-defaults/luci-ssr $(1)/etc/uci-defaults/luci-ssr
	$(INSTALL_DIR) $(1)/usr/bin
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-redir $(1)/usr/bin/ssr-redir
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-tunnel $(1)/usr/bin/ssr-tunnel	
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-local $(1)/usr/bin/ssr-local
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-check $(1)/usr/bin/ssr-check
	$(INSTALL_BIN) ./files/ssr.rule $(1)/usr/bin/ssrr-rules
	$(INSTALL_BIN) ./files/ssr.monitor $(1)/usr/bin/ssrr-monitor
	$(INSTALL_BIN) ./files/ssr.switch $(1)/usr/bin/ssrr-switch
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/ssr.config $(1)/etc/config/ssr
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) ./files/china_ssr.txt $(1)/etc/china_ssr.txt	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ssr.init $(1)/etc/init.d/ssr
endef

define Package/luci-app-shadowsocksR-Server/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/ssr.lua $(1)/usr/lib/lua/luci/controller/ssr.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./files/luci/i18n/ssr.*.lmo $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/ssr
	$(INSTALL_DATA) ./files/luci/model/cbi/ssr/*.lua $(1)/usr/lib/lua/luci/model/cbi/ssr/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/ssr
	$(INSTALL_DATA) ./files/luci/view/ssr/*.htm $(1)/usr/lib/lua/luci/view/ssr/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/root/etc/uci-defaults/luci-ssr $(1)/etc/uci-defaults/luci-ssr
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-server $(1)/usr/bin/ssrr-server		
	$(INSTALL_BIN) ./files/ssr.rule $(1)/usr/bin/ssrr-rules
	$(INSTALL_BIN) ./files/ssr.monitor $(1)/usr/bin/ssrr-monitor
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/ssr.config $(1)/etc/config/ssr
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ssr.init $(1)/etc/init.d/ssr
endef

define Package/luci-app-shadowsocksR-GFW/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/ssr.lua $(1)/usr/lib/lua/luci/controller/ssr.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./files/luci/i18n/ssr.*.lmo $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/ssr
	$(INSTALL_DATA) ./files/luci/model/cbi/ssr/*.lua $(1)/usr/lib/lua/luci/model/cbi/ssr/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/ssr
	$(INSTALL_DATA) ./files/luci/view/ssr/*.htm $(1)/usr/lib/lua/luci/view/ssr/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/root/etc/uci-defaults/luci-ssr $(1)/etc/uci-defaults/luci-ssr
	$(INSTALL_DIR) $(1)/usr/bin
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-redir $(1)/usr/bin/ssr-redir
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-tunnel $(1)/usr/bin/ssr-tunnel
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-local $(1)/usr/bin/ssr-local	
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-server $(1)/usr/bin/ssr-server		
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ss-check $(1)/usr/bin/ssr-check
	$(INSTALL_BIN) ./files/ssr.rule $(1)/usr/bin/ssrr-rules
	$(INSTALL_BIN) ./files/ssr.monitor $(1)/usr/bin/ssrr-monitor
	$(INSTALL_BIN) ./files/ssr.gfw $(1)/usr/bin/ssrr-gfw
	$(INSTALL_BIN) ./files/ssr.switch $(1)/usr/bin/ssrr-switch
	$(INSTALL_DIR) $(1)/etc/dnsmasq.ssr
	$(INSTALL_DATA) ./files/gfw_list.conf $(1)/etc/dnsmasq.ssr/gfw_list.conf
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/ssr.config $(1)/etc/config/ssr
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) ./files/china_ssr.txt $(1)/etc/china_ssr.txt	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ssr.init $(1)/etc/init.d/ssr
endef

#$(eval $(call BuildPackage,luci-app-shadowsocksR))
#$(eval $(call BuildPackage,luci-app-shadowsocksR-Client))
#$(eval $(call BuildPackage,luci-app-shadowsocksR-Server))
$(eval $(call BuildPackage,luci-app-shadowsocksR-GFW))
