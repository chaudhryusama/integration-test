"""This program performs required BGP application peer operations."""

# Copyright (c) 2015 Cisco Systems, Inc. and others.  All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html

__author__ = "Radovan Sajben"
__copyright__ = "Copyright(c) 2015, Cisco Systems, Inc."
__license__ = "Eclipse Public License v1.0"
__email__ = "rsajben@cisco.com"

import requests
import ipaddr
import argparse
import logging
import time
import xml.dom.minidom as md


def _build_url(odl_ip, port, uri):
    """Compose URL from generic IP, port and URI fragment.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

    Returns:
        :returns url: full restconf url corresponding to params
    """

    url = "http://" + str(odl_ip) + ":" + port + "/restconf/" + uri
    return url


def _build_data(xml_template, prefix_base, prefix_len, count, element="ipv4-routes"):
    """Generate list of routes based on xml templates.

    Args:
        :xml_template: xml template for routes

        :prefix_base: first prefix IP address

        :prefix_len: prefix length in bits

        :count: number of routes to be generated

        :element: element to be returned

    Returns:
        :returns xml_data: requested element as xml data
    """
    global total_build_data_time_counter
    build_data_timestamp = time.time()

    routes = md.parse(xml_template)

    routes_node = routes.getElementsByTagName("ipv4-routes")[0]
    route_node = routes.getElementsByTagName("ipv4-route")[0]
    if element == routes_node.tagName:
        routes_node.removeChild(route_node)
        if count:
            prefix_gap = 2 ** (32 - prefix_len)

        for prefix_index in range(count):
            new_route_node = route_node.cloneNode(True)
            new_route_prefix = new_route_node.getElementsByTagName("prefix")[0]

            prefix = prefix_base + prefix_index * prefix_gap
            new_route_prefix.childNodes[0].nodeValue = str(prefix) + "/" + str(prefix_len)

            routes_node.appendChild(new_route_node)

        xml_data = routes_node.toxml()
    elif element == route_node.tagName:
        route_node.setAttribute("xmlns", routes_node.namespaceURI)
        route_prefix = route_node.getElementsByTagName("prefix")[0]
        route_prefix.childNodes[0].nodeValue = str(prefix_base) + "/" + str(prefix_len)
        xml_data = route_node.toxml()
    else:
        xml_data = ""
    routes.unlink()
    logger.debug("xml data generated:\n%s", xml_data)
    total_build_data_time_counter += time.time() - build_data_timestamp
    return xml_data


def send_request(operation, odl_ip, port, uri, auth, xml_data=None, expect_status_code=200):
    """Send a http request.

    Args:
        :operation: GET, POST, PUT, DELETE

        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication credentials

        :param xml_data: list of routes as xml data

    Returns:
        :returns http response object
    """
    global total_response_time_counter
    global total_number_of_responses_counter

    ses = requests.Session()

    url = _build_url(odl_ip, port, uri)
    header = {"Content-Type": "application/xml"}
    req = requests.Request(operation, url, headers=header, data=xml_data, auth=auth)
    prep = req.prepare()
    try:
        send_request_timestamp = time.time()
        rsp = ses.send(prep, timeout=60)
        total_response_time_counter += time.time() - send_request_timestamp
        total_number_of_responses_counter += 1
    except requests.exceptions.Timeout:
        logger.error("No response from %s", odl_ip)
    else:
        logger.debug("%s %s", rsp.request, rsp.request.url)
        logger.debug("Request headers: %s:", rsp.request.headers)
        logger.debug("Request body: %s", rsp.request.body)
        logger.debug("Response: %s", rsp.text)
        if rsp.status_code == expect_status_code:
            logger.debug("%s %s", rsp.request, rsp.request.url)
            logger.debug("Request headers: %s:", rsp.request.headers)
            logger.debug("Request body: %s", rsp.request.body)
            logger.debug("Response: %s", rsp.text)
            logger.debug("%s %s", rsp, rsp.reason)
        else:
            logger.error("%s %s", rsp.request, rsp.request.url)
            logger.error("Request headers: %s:", rsp.request.headers)
            logger.error("Request body: %s", rsp.request.body)
            logger.error("Response: %s", rsp.text)
            logger.error("%s %s", rsp, rsp.reason)
        return rsp


def get_prefixes(odl_ip, port, uri, auth, prefix_base=None, prefix_len=None,
                 count=None, xml_template=None):
    """Send a http GET request for getting all prefixes.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix

        :prefix_len: length of the prefix in bites (specifies the increment as well)

        :param count: number of prefixes to be processed

        :param xml_template: xml template for building the xml data

    Returns:
        :returns None
    """

    logger.info("Get all prefixes from %s:%s/restconf/%s", odl_ip, port, uri)
    rsp = send_request("GET", odl_ip, port, uri, auth)
    if rsp is not None:
        s = rsp.text
        s = s.replace("{", "")
        s = s.replace("}", "")
        s = s.replace("[", "")
        s = s.replace("]", "")
        prefixes = ''
        prefix_count = 0
        for item in s.split(","):
            if "prefix" in item:
                prefixes += item + ","
                prefix_count += 1
        prefixes = prefixes[:len(prefixes)-1]
        logger.debug("prefix_list=%s", prefixes)
        logger.info("prefix_count=%s", prefix_count)


def post_prefixes(odl_ip, port, uri, auth, prefix_base=None, prefix_len=None,
                  count=0, xml_template=None):
    """Send a http POST request for creating a prefix list.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix

        :prefix_len: length of the prefix in bites (specifies the increment as well)

        :param count: number of prefixes to be processed

        :param xml_template: xml template for building the xml data (not used)

    Returns:
        :returns None
    """
    logger.info("Post %s prefix(es) in a single request (starting from %s/%s) into %s:%s/restconf/%s",
                count, prefix_base, prefix_len, odl_ip, port, uri)
    xml_data = _build_data(xml_template, prefix_base, prefix_len, count)
    send_request("POST", odl_ip, port, uri, auth, xml_data=xml_data, expect_status_code=204)


def put_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                 xml_template=None):
    """Send a http PUT request for updating the prefix list.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix

        :prefix_len: length of the prefix in bites (specifies the increment as well)

        :param count: number of prefixes to be processed

        :param xml_template: xml template for building the xml data (not used)

    Returns:
        :returns None
    """
    uri_add_prefix = uri + _uri_suffix_ipv4_routes
    logger.info("Put %s prefix(es) in a single request (starting from %s/%s) into %s:%s/restconf/%s",
                count, prefix_base, prefix_len, odl_ip, port, uri_add_prefix)
    xml_data = _build_data(xml_template, prefix_base, prefix_len, count)
    send_request("PUT", odl_ip, port, uri_add_prefix, auth, xml_data=xml_data)


def add_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                 xml_template=None):
    """Send a consequent http POST request for adding prefixes.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix

        :prefix_len: length of the prefix in bites (specifies the increment as well)

        :param count: number of prefixes to be processed

        :param xml_template: xml template for building the xml data (not used)

    Returns:
        :returns None
    """
    logger.info("Add %s prefixes (starting from %s/%s) into %s:%s/restconf/%s",
                count, prefix_base, prefix_len, odl_ip, port, uri)
    uri_add_prefix = uri + _uri_suffix_ipv4_routes
    prefix_gap = 2 ** (32 - prefix_len)
    for prefix_index in range(count):
        prefix = prefix_base + prefix_index * prefix_gap
        logger.info("Adding prefix %s/%s to %s:%s/restconf/%s",
                    prefix, prefix_len, odl_ip, port, uri)
        xml_data = _build_data(xml_template, prefix, prefix_len, 1, "ipv4-route")
        send_request("POST", odl_ip, port, uri_add_prefix, auth,
                     xml_data=xml_data, expect_status_code=204)


def delete_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                    xml_template=None):
    """Send a http DELETE requests for deleting prefixes.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix

        :prefix_len: length of the prefix in bites (specifies the increment as well)

        :param count: number of prefixes to be processed

        :param xml_template: xml template for building the xml data (not used)

    Returns:
        :returns None
    """
    logger.info("Delete %s prefix(es) (starting from %s/%s) from %s:%s/restconf/%s",
                count, prefix_base, prefix_len, odl_ip, port, uri)
    uri_del_prefix = uri + _uri_suffix_ipv4_routes + _uri_suffix_ipv4_route
    prefix_gap = 2 ** (32 - prefix_len)
    for prefix_index in range(count):
        prefix = prefix_base + prefix_index * prefix_gap
        logger.info("Deleting prefix %s/%s from %s:%s/restconf/%s",
                    prefix, prefix_len, odl_ip, port, uri)
        send_request("DELETE", odl_ip, port,
                     uri_del_prefix + str(prefix) + "%2F" + str(prefix_len), auth)


def delete_all_prefixes(odl_ip, port, uri, auth, prefix_base=None,
                        prefix_len=None, count=None, xml_template=None):
    """Send a http DELETE request for deleting all prefixes.

    Args:
        :param odl_ip: controller's ip address or hostname

        :param port: controller's restconf port

        :param uri: URI without /restconf/ to complete URL

        :param auth: authentication tupple as (user, password)

        :param prefix_base: IP address of the first prefix (not used)

        :prefix_len: length of the prefix in bites (not used)

        :param count: number of prefixes to be processed (not used)

        :param xml_template: xml template for building the xml data (not used)

    Returns:
        :returns None
    """
    logger.info("Delete all prefixes from %s:%s/restconf/%s", odl_ip, port, uri)
    uri_del_all_prefixes = uri + _uri_suffix_ipv4_routes
    send_request("DELETE", odl_ip, port, uri_del_all_prefixes, auth)


_commands = ["post", "put", "add", "delete", "delete-all", "get"]
_uri_suffix_ipv4_routes = "bgp-inet:ipv4-routes/"
_uri_suffix_ipv4_route = "bgp-inet:ipv4-route/"   # followed by IP address like 1.1.1.1%2F32

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="BGP application peer script")
    parser.add_argument("--host", type=ipaddr.IPv4Address, default="127.0.0.1",
                        help="ODL controller IP address")
    parser.add_argument("--port", default="8181",
                        help="ODL RESTCONF port")
    parser.add_argument("--command", choices=_commands, metavar="command",
                        help="Command to be performed."
                        "post, put, add, delete, delete-all, get")
    parser.add_argument("--prefix", type=ipaddr.IPv4Address, default="8.0.1.0",
                        help="First prefix IP address")
    parser.add_argument("--prefixlen", type=int, help="Prefix length in bites",
                        default=28)
    parser.add_argument("--count", type=int, help="Number of prefixes",
                        default=1)
    parser.add_argument("--user", help="Restconf user name", default="admin")
    parser.add_argument("--password", help="Restconf password", default="admin")
    parser.add_argument("--uri", help="The uri part of requests",
                        default="config/bgp-rib:application-rib/example-app-rib/"
                                "tables/bgp-types:ipv4-address-family/"
                                "bgp-types:unicast-subsequent-address-family/")
    parser.add_argument("--xml", help="File name of the xml data template",
                        default="ipv4-routes-template.xml")
    parser.add_argument("--error", dest="loglevel", action="store_const",
                        const=logging.ERROR, default=logging.INFO,
                        help="Set log level to error (default is info)")
    parser.add_argument("--warning", dest="loglevel", action="store_const",
                        const=logging.WARNING, default=logging.INFO,
                        help="Set log level to warning (default is info)")
    parser.add_argument("--info", dest="loglevel", action="store_const",
                        const=logging.INFO, default=logging.INFO,
                        help="Set log level to info (default is info)")
    parser.add_argument("--debug", dest="loglevel", action="store_const",
                        const=logging.DEBUG, default=logging.INFO,
                        help="Set log level to debug (default is info)")
    parser.add_argument("--logfile", default="bgp_app_peer.log", help="Log file name")

    args = parser.parse_args()

    logger = logging.getLogger("logger")
    log_formatter = logging.Formatter("%(asctime)s %(levelname)s: %(message)s")
    console_handler = logging.StreamHandler()
    file_handler = logging.FileHandler(args.logfile, mode="w")
    console_handler.setFormatter(log_formatter)
    file_handler.setFormatter(log_formatter)
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    logger.setLevel(args.loglevel)

    auth = (args.user, args.password)

    odl_ip = args.host
    port = args.port
    command = args.command
    prefix_base = args.prefix
    prefix_len = args.prefixlen
    count = args.count
    auth = (args.user, args.password)
    uri = args.uri
    xml_template = args.xml

    test_start_time = time.time()
    total_build_data_time_counter = 0
    total_response_time_counter = 0
    total_number_of_responses_counter = 0

    if command == "post":
        post_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                      xml_template)
    if command == "put":
        put_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                     xml_template)
    if command == "add":
        add_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count,
                     xml_template)
    elif command == "delete":
        delete_prefixes(odl_ip, port, uri, auth, prefix_base, prefix_len, count)
    elif command == "delete-all":
        delete_all_prefixes(odl_ip, port, uri, auth)
    elif command == "get":
        get_prefixes(odl_ip, port, uri, auth)

    total_test_execution_time = time.time() - test_start_time

    logger.info("Total test execution time: %.3fs", total_test_execution_time)
    logger.info("Total build data time: %.3fs", total_build_data_time_counter)
    logger.info("Total response time: %.3fs", total_response_time_counter)
    logger.info("Total number of response(s): %s", total_number_of_responses_counter)
    file_handler.close()
