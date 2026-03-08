# ABOUTME: CLI tool to manage port forwarding (NAT) rules on SFR Box routers.
# ABOUTME: Uses reverse-engineered web API with HMAC-SHA256 challenge-response auth.

import argparse
import hashlib
import hmac
import os
import re
import sys

import requests
from bs4 import BeautifulSoup


class SFRBoxNAT:
    """Client for managing NAT rules on an SFR Box router."""

    def __init__(self, host="192.168.1.1", login="admin", password=None):
        self.base_url = f"http://{host}"
        self.login_user = login
        self.password = password
        self.session = requests.Session()

    def authenticate(self):
        """Perform challenge-response authentication against the SFR Box."""
        # Step 0: Visit login page to establish initial session
        self.session.get(f"{self.base_url}/login?page_ref=/network/nat")

        # Step 1: Request a challenge nonce (must be sent as AJAX)
        resp = self.session.post(
            f"{self.base_url}/login",
            data={"action": "challenge"},
            headers={"X-Requested-With": "XMLHttpRequest"},
        )

        # The response is XML-like; extract the challenge value
        challenge = self._extract_challenge(resp.text)
        if not challenge:
            raise RuntimeError("Failed to obtain authentication challenge")

        # Step 2: Compute HMAC-SHA256 hash
        login_hash = hashlib.sha256(self.login_user.encode()).hexdigest()
        password_hash = hashlib.sha256(self.password.encode()).hexdigest()

        login_hmac = hmac.new(
            challenge.encode(), login_hash.encode(), hashlib.sha256
        ).hexdigest()
        password_hmac = hmac.new(
            challenge.encode(), password_hash.encode(), hashlib.sha256
        ).hexdigest()

        combined_hash = login_hmac + password_hmac

        # Step 3: Submit login form
        resp = self.session.post(
            f"{self.base_url}/login",
            data={
                "method": "passwd",
                "page_ref": "/network/nat",
                "zsid": challenge,
                "hash": combined_hash,
                "login": "",
                "password": "",
            },
            allow_redirects=True,
        )

        # Verify authentication succeeded by checking we can access the NAT page
        if "form_auth_passwd" in resp.text:
            raise RuntimeError(
                "Authentication failed — check login credentials"
            )

        return True

    def _extract_challenge(self, response_text):
        """Extract challenge nonce from the server's XML/HTML response."""
        # Try XML-style: <challenge>value</challenge>
        match = re.search(r"<challenge>(.*?)</challenge>", response_text)
        if match:
            return match.group(1)
        # Try JSON-style: "challenge":"value"
        match = re.search(r'"challenge"\s*:\s*"(.*?)"', response_text)
        if match:
            return match.group(1)
        return None

    def list_rules(self):
        """Fetch and parse the current NAT rules from the router."""
        resp = self.session.get(f"{self.base_url}/network/nat")
        resp.raise_for_status()
        return self._parse_rules(resp.text)

    def _parse_rules(self, html):
        """Parse NAT rules from the HTML table."""
        soup = BeautifulSoup(html, "html.parser")
        table = soup.find("table", id="nat_config")
        if not table:
            raise RuntimeError("Could not find NAT config table in response")

        rules = []
        for row in table.find("tbody").find_all("tr"):
            # Skip the "add new rule" form row (no span.col_number)
            number_cell = row.find("td", {"data-title": "#"})
            if not number_cell:
                continue
            number_span = number_cell.find("span", class_="col_number")
            if not number_span:
                continue

            # Extract rule data from cells
            name = row.find("td", {"data-title": "Name"}).get_text(strip=True)
            protocol = row.find("td", {"data-title": "Protocol"}).get_text(strip=True)
            rule_type = row.find("td", {"data-title": "Type"}).get_text(strip=True)
            ext_ports = row.find("td", {"data-title": "External ports"}).get_text(strip=True)
            ip_address = row.find("td", {"data-title": "IP address"}).get_text(strip=True)
            dst_ports = row.find("td", {"data-title": "Destination ports"}).get_text(strip=True)

            # Determine enabled/disabled state and rule index from the button
            activation_cell = row.find("td", {"data-title": "Activation"})
            button = activation_cell.find("input", {"type": "submit"})
            if button:
                btn_name = button.get("name", "")
                btn_value = button.get("value", "")
                # "Disable" button means currently enabled; "Enable" means disabled
                enabled = btn_value == "Disable"
                # Extract index from button name (e.g., "action_disable.5" → 5)
                idx_match = re.search(r"\.(\d+)$", btn_name)
                index = int(idx_match.group(1)) if idx_match else None
            else:
                enabled = False
                index = None

            rules.append({
                "number": number_span.get_text(strip=True),
                "index": index,
                "name": name,
                "protocol": protocol,
                "type": rule_type,
                "ext_ports": ext_ports,
                "ip_address": ip_address,
                "dst_ports": dst_ports,
                "enabled": enabled,
            })

        return rules

    def _build_port_lists(self, rules):
        """Build port_list_tcp and port_list_udp from current rules."""
        tcp_ports = []
        udp_ports = []
        for rule in rules:
            proto = rule["protocol"].upper()
            port = rule["ext_ports"]
            if proto in ("TCP", "BOTH"):
                tcp_ports.append(port)
            if proto in ("UDP", "BOTH"):
                udp_ports.append(port)
        tcp_str = ":" + ":".join(tcp_ports) + ":" if tcp_ports else ":"
        udp_str = ":" + ":".join(udp_ports) + ":" if udp_ports else ":"
        return tcp_str, udp_str

    def _resolve_rule(self, rules, name_or_index):
        """Find a rule by name or index number."""
        # Try as index first
        try:
            idx = int(name_or_index)
            for rule in rules:
                if rule["index"] == idx:
                    return rule
        except ValueError:
            pass

        # Try as name (case-insensitive)
        for rule in rules:
            if rule["name"].lower() == name_or_index.lower():
                return rule

        raise ValueError(f"No rule found matching '{name_or_index}'")

    def _parse_ip_octet(self, ip_input):
        """Parse IP input — accepts last octet (e.g. '74') or full IP (e.g. '192.168.1.74')."""
        ip_str = str(ip_input)
        if "." in ip_str:
            parts = ip_str.split(".")
            if len(parts) != 4 or parts[:3] != ["192", "168", "1"]:
                raise ValueError(
                    f"IP must be in 192.168.1.x range, got '{ip_str}'"
                )
            return parts[3]
        # Just the last octet
        octet = int(ip_str)
        if not 1 <= octet <= 254:
            raise ValueError(f"IP last octet must be 1-254, got {octet}")
        return str(octet)

    def _build_rule_payload(self, rule):
        """Build the common rule fields payload from a rule dict."""
        ip_parts = rule["ip_address"].split(".")
        return {
            "nat_rulename": rule["name"],
            "nat_proto": rule["protocol"].lower(),
            "nat_range": "false" if rule["type"] == "Port" else "true",
            "nat_extport": rule["ext_ports"],
            "nat_extrange_p0": "",
            "nat_extrange_p1": "",
            "nat_dstip_p0": ip_parts[0],
            "nat_dstip_p1": ip_parts[1],
            "nat_dstip_p2": ip_parts[2],
            "nat_dstip_p3": ip_parts[3],
            "nat_dstport": rule["dst_ports"],
            "nat_dstrange_p0": "",
            "nat_dstrange_p1": "",
            "nat_active": "on" if rule["enabled"] else "",
        }

    def add_rule(self, name, ext_port, ip_last_octet, dst_port,
                 proto="tcp", active=True):
        """Add a new NAT port forwarding rule."""
        octet = self._parse_ip_octet(ip_last_octet)
        rules = self.list_rules()
        tcp_list, udp_list = self._build_port_lists(rules)

        payload = {
            "port_list_tcp": tcp_list,
            "port_list_udp": udp_list,
            "nat_rulename": name,
            "nat_proto": proto,
            "nat_range": "false",
            "nat_extport": str(ext_port),
            "nat_extrange_p0": "",
            "nat_extrange_p1": "",
            "nat_dstip_p0": "192",
            "nat_dstip_p1": "168",
            "nat_dstip_p2": "1",
            "nat_dstip_p3": octet,
            "nat_dstport": str(dst_port),
            "nat_dstrange_p0": "",
            "nat_dstrange_p1": "",
            "nat_active": "on" if active else "",
            "action_add": "",
        }

        resp = self.session.post(
            f"{self.base_url}/network/nat", data=payload
        )
        resp.raise_for_status()
        return self._parse_rules(resp.text)

    def delete_rule(self, name_or_index):
        """Delete a NAT rule by name or index."""
        rules = self.list_rules()
        rule = self._resolve_rule(rules, name_or_index)
        tcp_list, udp_list = self._build_port_lists(rules)

        payload = {
            "port_list_tcp": tcp_list,
            "port_list_udp": udp_list,
            f"action_remove.{rule['index']}": "",
        }
        payload.update(self._build_rule_payload(rule))

        resp = self.session.post(
            f"{self.base_url}/network/nat", data=payload
        )
        resp.raise_for_status()
        return self._parse_rules(resp.text)

    def enable_rule(self, name_or_index):
        """Enable a NAT rule by name or index."""
        rules = self.list_rules()
        rule = self._resolve_rule(rules, name_or_index)
        tcp_list, udp_list = self._build_port_lists(rules)

        payload = {
            "port_list_tcp": tcp_list,
            "port_list_udp": udp_list,
            f"action_enable.{rule['index']}": "Enable",
        }
        payload.update(self._build_rule_payload(rule))

        resp = self.session.post(
            f"{self.base_url}/network/nat", data=payload
        )
        resp.raise_for_status()
        return self._parse_rules(resp.text)

    def disable_rule(self, name_or_index):
        """Disable a NAT rule by name or index."""
        rules = self.list_rules()
        rule = self._resolve_rule(rules, name_or_index)
        tcp_list, udp_list = self._build_port_lists(rules)

        payload = {
            "port_list_tcp": tcp_list,
            "port_list_udp": udp_list,
            f"action_disable.{rule['index']}": "Disable",
        }
        payload.update(self._build_rule_payload(rule))

        resp = self.session.post(
            f"{self.base_url}/network/nat", data=payload
        )
        resp.raise_for_status()
        return self._parse_rules(resp.text)


def print_rules(rules):
    """Display rules as a formatted table."""
    if not rules:
        print("No NAT rules configured.")
        return

    # Column headers and widths
    headers = ["#", "Name", "Proto", "Type", "Ext Port", "IP Address", "Dst Port", "Status"]
    rows = []
    for r in rules:
        status = "enabled" if r["enabled"] else "disabled"
        rows.append([
            r["number"],
            r["name"],
            r["protocol"],
            r["type"],
            r["ext_ports"],
            r["ip_address"],
            r["dst_ports"],
            status,
        ])

    # Calculate column widths
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))

    # Print header
    header_line = "  ".join(h.ljust(widths[i]) for i, h in enumerate(headers))
    print(header_line)
    print("  ".join("-" * w for w in widths))

    # Print rows
    for row in rows:
        print("  ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def create_client():
    """Create and authenticate an SFRBoxNAT client from environment variables."""
    password = os.environ.get("SFR_BOX_PASSWORD")
    if not password:
        print("Error: SFR_BOX_PASSWORD environment variable is not set.", file=sys.stderr)
        print("Add it to your .secrets.sh file:", file=sys.stderr)
        print('  export SFR_BOX_PASSWORD="your_password"', file=sys.stderr)
        sys.exit(1)

    login = os.environ.get("SFR_BOX_LOGIN", "admin")
    host = os.environ.get("SFR_BOX_HOST", "192.168.1.1")

    client = SFRBoxNAT(host=host, login=login, password=password)
    client.authenticate()
    return client


def main():
    parser = argparse.ArgumentParser(
        description="Manage NAT port forwarding rules on SFR Box router"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    subparsers.add_parser("list", help="List all port forwarding rules")

    # add
    add_parser = subparsers.add_parser("add", help="Add a port forwarding rule")
    add_parser.add_argument("name", help="Rule name (max 20 chars)")
    add_parser.add_argument("ext_port", type=int, help="External port (1-65535)")
    add_parser.add_argument("ip", help="Destination IP (last octet or full 192.168.1.x)")
    add_parser.add_argument("dst_port", type=int, help="Destination port (1-65535)")
    add_parser.add_argument(
        "--proto", choices=["tcp", "udp", "both"], default="tcp",
        help="Protocol (default: tcp)"
    )
    add_parser.add_argument(
        "--disabled", action="store_true",
        help="Add the rule in disabled state"
    )

    # delete
    del_parser = subparsers.add_parser("delete", help="Delete a port forwarding rule")
    del_parser.add_argument("rule", help="Rule name or index number")

    # enable
    en_parser = subparsers.add_parser("enable", help="Enable a port forwarding rule")
    en_parser.add_argument("rule", help="Rule name or index number")

    # disable
    dis_parser = subparsers.add_parser("disable", help="Disable a port forwarding rule")
    dis_parser.add_argument("rule", help="Rule name or index number")

    args = parser.parse_args()

    client = create_client()

    if args.command == "list":
        rules = client.list_rules()
        print_rules(rules)

    elif args.command == "add":
        if len(args.name) > 20:
            print(f"Error: Rule name must be 20 chars or less, got {len(args.name)}", file=sys.stderr)
            sys.exit(1)
        rules = client.add_rule(
            name=args.name,
            ext_port=args.ext_port,
            ip_last_octet=args.ip,
            dst_port=args.dst_port,
            proto=args.proto,
            active=not args.disabled,
        )
        print(f"Added rule '{args.name}'")
        print_rules(rules)

    elif args.command == "delete":
        rules = client.delete_rule(args.rule)
        print(f"Deleted rule '{args.rule}'")
        print_rules(rules)

    elif args.command == "enable":
        rules = client.enable_rule(args.rule)
        print(f"Enabled rule '{args.rule}'")
        print_rules(rules)

    elif args.command == "disable":
        rules = client.disable_rule(args.rule)
        print(f"Disabled rule '{args.rule}'")
        print_rules(rules)


if __name__ == "__main__":
    main()
