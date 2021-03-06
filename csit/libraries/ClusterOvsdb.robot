*** Settings ***
Documentation     Cluster Ovsdb library. So far this library is only to be used by Ovsdb cluster test as it is very specific for this test.
Library           RequestsLibrary
Resource          ClusterKeywords.robot
Resource          MininetKeywords.robot
Resource          Utils.robot
Resource          OVSDB.robot
Variables         ../variables/Variables.py

*** Keywords ***
Check Ovsdb Shards Status
    [Arguments]    ${controller_index_list}
    [Documentation]    Check Status for all shards in Ovsdb application.
    ${topo_conf_leader}    ${topo_conf_followers_list}    Get Cluster Shard Status    ${controller_index_list}    config    topology
    ${topo_oper_leader}    ${topo_oper_followers_list}    Get Cluster Shard Status    ${controller_index_list}    operational    topology
    ${owner_oper_leader}    ${owner_oper_followers_list}    Get Cluster Shard Status    ${controller_index_list}    operational    entity-ownership
    Log    config topology Leader is ${topo_conf_leader} and followers are ${topo_conf_followers_list}
    Log    operational topology Leader is ${topo_oper_leader} and followers are ${topo_oper_followers_list}
    Log    operational entity-ownership Leader is ${owner_oper_leader} and followers are ${owner_oper_followers_list}

Check Ovsdb Shards Status After Cluster Event
    [Arguments]    ${controller_index_list}
    [Documentation]    Check Shard Status after some cluster event.
    Wait Until Keyword Succeeds    90s    1s    Check Ovsdb Shards Status    ${controller_index_list}

Get Ovsdb Entity Owner Status For One Device
    [Arguments]    ${controller_index_list}
    [Documentation]    Check Entity Owner Status and identify owner and candidate.
    ${owner}    ${candidates_list}    Wait Until Keyword Succeeds    20s    1s    Get Cluster Entity Owner For Ovsdb    ${controller_index_list}
    ...    ovsdb    ovsdb:1
    [Return]    ${owner}    ${candidates_list}

Get Cluster Entity Owner For Ovsdb
    [Arguments]    ${controller_index_list}    ${device_type}    ${device}
    [Documentation]    Checks Entity Owner status for a ${device} and returns owner index and list of candidates from a ${controller_index_list}.
    ...    ${device_type} is openflow, ovsdb, etc...
    ${length}=    Get Length    ${controller_index_list}
    ${candidates_list}=    Create List
    ${data}=    Get Data From URI    controller@{controller_index_list}[0]    /restconf/operational/entity-owners:entity-owners
    Log    ${data}
    ${data}=    Replace String    ${data}    /network-topology:network-topology/network-topology:topology[network-topology:topology-id='    ${EMPTY}
    # the UUID will not always be the same so need to use regexp to remove this string
    ${data}=    Replace String Using Regexp    ${data}    \/network-topology:node\\[network-topology:node-id='ovsdb://uuid/........-....-....-....-............    ${EMPTY}
    Log    ${data}
    ${clear_data}=    Replace String    ${data}    ']    ${EMPTY}
    Log    ${clear_data}
    ${json}=    To Json    ${clear_data}
    ${entity_type_list}=    Get From Dictionary    &{json}[entity-owners]    entity-type
    ${entity_type_index}=    Get Index From List Of Dictionaries    ${entity_type_list}    type    ${device_type}
    Should Not Be Equal    ${entity_type_index}    -1    No Entity Owner found for ${device_type}
    ${entity_list}=    Get From Dictionary    @{entity_type_list}[${entity_type_index}]    entity
    ${entity_index}=    Get Index From List Of Dictionaries    ${entity_list}    id    ${device}
    Should Not Be Equal    ${entity_index}    -1    Device ${device} not found in Entity Owner ${device_type}
    ${entity_owner}=    Get From Dictionary    @{entity_list}[${entity_index}]    owner
    Should Not Be Empty    ${entity_owner}    No owner found for ${device}
    ${owner}=    Replace String    ${entity_owner}    member-    ${EMPTY}
    ${owner}=    Convert To Integer    ${owner}
    List Should Contain Value    ${controller_index_list}    ${owner}    Owner ${owner} not exisiting in ${controller_index_list}
    ${entity_candidates_list}=    Get From Dictionary    @{entity_list}[${entity_index}]    candidate
    ${list_length}=    Get Length    ${entity_candidates_list}
    : FOR    ${entity_candidate}    IN    @{entity_candidates_list}
    \    ${candidate}=    Replace String    &{entity_candidate}[name]    member-    ${EMPTY}
    \    ${candidate}=    Convert To Integer    ${candidate}
    \    Run Keyword If    '${candidate}' != '${owner}'    Append To List    ${candidates_list}    ${candidate}
    [Return]    ${owner}    ${candidates_list}

Create Bridge And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}    ${status}=${NONE}
    [Documentation]    Create bridge in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    # need to get UUID which should be the same on all controllers in cluster, so asking controller1
    ${ovsdb_uuid}=    Get OVSDB UUID    controller_http_session=controller${controller_index}
    Set Suite Variable    ${ovsdb_uuid}
    ${body}=    OperatingSystem.Get File    ${CURDIR}/../variables/ovsdb/create_bridge_3node.json
    ${body}    Replace String    ${body}    ovsdb://127.0.0.1:61644    ovsdb://uuid/${ovsdb_uuid}
    ${body}    Replace String    ${body}    tcp:controller1:6633    tcp:${ODL_SYSTEM_1_IP}:6640
    ${body}    Replace String    ${body}    tcp:controller2:6633    tcp:${ODL_SYSTEM_2_IP}:6640
    ${body}    Replace String    ${body}    tcp:controller3:6633    tcp:${ODL_SYSTEM_3_IP}:6640
    ${body}    Replace String    ${body}    127.0.0.1    ${TOOLS_SYSTEM_IP}
    ${BRIDGE}=    Set Variable If    "${status}"=="AfterFail"    br02    br01
    Log    ${BRIDGE}
    ${body}    Replace String    ${body}    br01    ${BRIDGE}
    ${body}    Replace String    ${body}    61644    ${OVSDB_PORT}
    Log    ${body}
    ${TOOLS_SYSTEM_IP1}    Replace String    ${TOOLS_SYSTEM_IP}    ${TOOLS_SYSTEM_IP}    "${TOOLS_SYSTEM_IP}"
    ${dictionary}=    Create Dictionary    ${TOOLS_SYSTEM_IP1}=1    ${OVSDBPORT}=4    ${BRIDGE}=1
    Wait Until Keyword Succeeds    20s    1s    Put And Check At URI In Cluster    ${controller_index_list}    ${controller_index}    ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}
    ...    ${body}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}

Create Bridge Manually And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}
    [Documentation]    Create bridge in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl add-br br-s1
    ${dictionary_operational}=    Create Dictionary    br-s1=5
    ${dictionary_config}=    Create Dictionary    br-s1=0
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary_config}    ${CONFIG_TOPO_API}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary_operational}    ${OPERATIONAL_TOPO_API}

Delete Bridge Manually And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}
    [Documentation]    Delete bridge in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl del-br br-s1
    ${dictionary}=    Create Dictionary    br-s1=0
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}

Delete Bridge Via Rest Call And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}
    [Documentation]    Delete bridge in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    # need to get UUID which should be the same on all controllers in cluster, so asking controller1
    ${ovsdb_uuid}=    Get OVSDB UUID    controller_http_session=controller${controller_index}
    ${dictionary}=    Create Dictionary    ${BRIDGE}=0
    Wait Until Keyword Succeeds    20s    1s    Delete And Check At URI In Cluster    ${controller_index_list}    ${controller_index}    ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}

Create Port Via Controller
    [Arguments]    ${controller_index_list}    ${controller_index}    ${status}=${NONE}
    [Documentation]    This will add port/interface to the config datastore
    ${sample}    OperatingSystem.Get File    ${OVSDB_CONFIG_DIR}/create_port_3node.json
    ${body}    Replace String    ${sample}    192.168.1.10    ${TOOLS_SYSTEM_IP}
    Log    ${body}
    ${BRIDGE}=    Set Variable If    "${status}"=="AfterFail"    br02    br01
    Log    ${BRIDGE}
    Log    URL is ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}/termination-point/vx2/
    ${port_dictionary}=    Create Dictionary    ${BRIDGE}=7    vx2=3
    Put And Check At URI In Cluster    ${controller_index_list}    ${controller_index}    ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}/termination-point/vx2/    ${body}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${port_dictionary}    ${OPERATIONAL_TOPO_API}

Modify the destination IP of Port
    [Arguments]    ${controller_index_list}    ${controller_index}    ${status}=${NONE}
    [Documentation]    This will modify the dst ip of existing port
    ${sample}    OperatingSystem.Get File    ${OVSDB_CONFIG_DIR}/create_port_3node.json
    ${body}    Replace String    ${sample}    192.168.1.10    10.0.0.19
    ${BRIDGE}=    Set Variable If    "${status}"=="AfterFail"    br02    br01
    Log    URL is ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}/termination-point/vx2/
    Log    ${body}
    Put And Check At URI In Cluster    ${controller_index_list}    ${controller_index}    ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}/termination-point/vx2/    ${body}

Delete Port And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}    ${status}=${NONE}
    [Documentation]    Delete port in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    ${dictionary}=    Create Dictionary    vx2=0
    ${BRIDGE}=    Set Variable If    "${status}"=="AfterFail"    br02    br01
    Delete And Check At URI In Cluster    ${controller_index_list}    ${controller_index}    ${CONFIG_TOPO_API}/topology/ovsdb:1/node/ovsdb:%2F%2Fuuid%2F${ovsdb_uuid}%2Fbridge%2F${BRIDGE}/termination-point/vx2/
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}

Add Port To The Manual Bridge And Verify
    [Arguments]    ${controller_index_list}    ${controller_index}
    [Documentation]    Add Port in ${controller_index} and verify it gets applied in all instances in ${controller_index_list}.
    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl add-port br-s1 vx1 -- set Interface vx1 type=vxlan
    ${dictionary_operational}=    Create Dictionary    vx1=2
    ${dictionary_config}=    Create Dictionary    vx1=0
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary_config}    ${CONFIG_TOPO_API}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary_operational}    ${OPERATIONAL_TOPO_API}

Get Operational Topology with modified Port
    [Arguments]    ${controller_index_list}    ${controller_index}    ${status}=${NONE}
    [Documentation]    This request will fetch the operational topology after the Port is added to the bridge
    ${port_dictionary_before_fail}    Create Dictionary    br01=7    vx2=3    10.0.0.19=1
    ${port_dictionary_after_fail}    Create Dictionary    br02=7    vx2=3    10.0.0.19=1
    ${port_dictionary}=    Set Variable If    "${status}"=="AfterFail"    ${port_dictionary_after_fail}    ${port_dictionary_before_fail}
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${port_dictionary}    ${OPERATIONAL_TOPO_API}

Verify Bridge in Restarted Node
    [Arguments]    ${controller_index_list}
    [Documentation]    Verify Bridge in Restarted node, which is created when the node is down.
    ${dictionary}    Create Dictionary    br02=6
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}

Verify Port in Restarted Node
    [Arguments]    ${controller_index_list}
    [Documentation]    Verify Port in Restarted node, which is created when the node is down.
    ${dictionary}    Create Dictionary    vx2=3
    Wait Until Keyword Succeeds    5s    1s    Check Item Occurrence At URI In Cluster    ${controller_index_list}    ${dictionary}    ${OPERATIONAL_TOPO_API}
