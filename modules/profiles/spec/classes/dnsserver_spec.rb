# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::dnsserver' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      it { is_expected.to compile }
      it {
        is_expected.to contain_file('/opt')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('/opt/docker-compose')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('/opt/docker-compose/dnsserver/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('docker-compose')
          .with(ensure: 'file')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0644')
          .with(path: '/opt/docker-compose/dnsserver/docker-compose.yml')
        is_expected.to contain_docker_compose('pihole')
          .with(ensure: 'present')
          .with(compose_files: ['/opt/docker-compose/dnsserver/docker-compose.yml'])
          .with(subscribe: 'File[docker-compose]')
        is_expected.to contain_firewall('100 allow http to 192.168.0.0/16')
          .with(destination: '192.168.0.0/16')
          .with(source: '192.168.0.0/16')
          .with(dport: ['1080'])
          .with(proto: 'tcp')
          .with(action: 'accept')
      }
      context "with no param set" do
        it {
          verify_contents(catalogue, "docker-compose", [
            "version: '3'",
            "services:",
            "  pihole:",
            "    container_name: pihole",
            "    image: pihole/pihole:latest",
            "    ports:",
            "      - '53:53/tcp'",
            "      - '53:53/udp'",
            "      - '1080:80/tcp'",
            "    environment:",
            "      TZ: 'Europe/Paris'",
            "      WEBPASSWORD: 'root'",
            "    volumes:",
            "      - '/opt/pihole/etc:/etc/pihole'",
            "      - '/opt/pihole/dnsmasq.d:/etc/dnsmasq.d'",
            "    restart: unless-stopped"
          ])
        }
      end
      context "with dhcp param explicitely disabled" do
        let(:params) {{ 'enable_dhcp_server' => false }}
        it {
          verify_contents(catalogue, "docker-compose", [
            "version: '3'",
            "services:",
            "  pihole:",
            "    container_name: pihole",
            "    image: pihole/pihole:latest",
            "    ports:",
            "      - '53:53/tcp'",
            "      - '53:53/udp'",
            "      - '1080:80/tcp'",
            "    environment:",
            "      TZ: 'Europe/Paris'",
            "      WEBPASSWORD: 'root'",
            "    volumes:",
            "      - '/opt/pihole/etc:/etc/pihole'",
            "      - '/opt/pihole/dnsmasq.d:/etc/dnsmasq.d'",
            "    restart: unless-stopped"
          ])
        }
      end
      context "with dhcp param enabled" do
        let(:params) {{ 'enable_dhcp_server' => true }}
        it {
          verify_contents(catalogue, "docker-compose", [
            "version: '3'",
            "services:",
            "  pihole:",
            "    container_name: pihole",
            "    image: pihole/pihole:latest",
            "    network_mode: 'host'",
            "    cap_add:",
            "      - NET_ADMIN",
            "    environment:",
            "      TZ: 'Europe/Paris'",
            "      WEBPASSWORD: 'root'",
            "    volumes:",
            "      - '/opt/pihole/etc:/etc/pihole'",
            "      - '/opt/pihole/dnsmasq.d:/etc/dnsmasq.d'",
            "    restart: unless-stopped"
          ])
        }
      end
    end
  end
end
