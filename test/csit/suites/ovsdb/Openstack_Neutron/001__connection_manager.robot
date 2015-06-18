*** Settings ***
Documentation     Test suite connecting ODL to Mininet
Resource          ../../../libraries/Utils.txt

*** Variables ***
${FLOWS_TABLE_20}    actions=goto_table:20
${FLOW_CONTROLLER}    actions=CONTROLLER:65535
${FLOWS_TABLE_30}    actions=goto_table:30
${FLOWS_TABLE_40}    actions=goto_table:40
${FLOWS_TABLE_50}    actions=goto_table:50
${FLOWS_TABLE_60}    actions=goto_table:60
${FLOWS_TABLE_70}    actions=goto_table:70
${FLOWS_TABLE_80}    actions=goto_table:80
${FLOWS_TABLE_90}    actions=goto_table:90
${FLOWS_TABLE_100}    actions=goto_table:100
${FLOWS_TABLE_110}    actions=goto_table:110
${FLOW_DROP}      actions=drop

*** Test Cases ***
Make the OVS instance to listen for connection
    [Documentation]    Connect OVS to ODL
    [Tags]    OVSDB netvirt
    Run Command On Remote System    ${MININET}    sudo ovs-vsctl del-manager
    Run Command On Remote System    ${MININET}    sudo ovs-vsctl set-manager tcp:${CONTROLLER}:6640
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-vsctl show

Get controller connection
    [Documentation]    This will make sure the controller is correctly set up/connected
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-vsctl show
    Should Contain    ${output}    Manager "tcp:${CONTROLLER}:6640"
    Should Contain    ${output}    is_connected: true

Get bridge setup
    [Documentation]    This request is verifying that the br-int bridge has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-vsctl show
    Should Contain    ${output}    Controller "tcp:${CONTROLLER}:6653"
    Should Contain    ${output}    Bridge br-int

Get port setup
    [Documentation]    This will check the port br-int has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-vsctl show
    Should Contain    ${output}    Port br-int

Get interface setup
    [Documentation]    This verify the interface br-int has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-vsctl show
    Should Contain    ${output}    Interface br-int

Get the bridge flows
    [Documentation]    This request fetch the OF13 flow tables to verify the flows are correctly added
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${MININET}    sudo ovs-ofctl -O Openflow13 dump-flows br-int
    Should Contain    ${output}    ${FLOWS_TABLE_20}
    Should Contain    ${output}    ${FLOW_CONTROLLER}
    Should Contain    ${output}    ${FLOWS_TABLE_30}
    Should Contain    ${output}    ${FLOWS_TABLE_40}
    Should Contain    ${output}    ${FLOWS_TABLE_50}
    Should Contain    ${output}    ${FLOWS_TABLE_60}
    Should Contain    ${output}    ${FLOWS_TABLE_70}
    Should Contain    ${output}    ${FLOWS_TABLE_80}
    Should Contain    ${output}    ${FLOWS_TABLE_90}
    Should Contain    ${output}    ${FLOWS_TABLE_100}
    Should Contain    ${output}    ${FLOWS_TABLE_110}
    Should Contain    ${output}    ${FLOW_DROP}
