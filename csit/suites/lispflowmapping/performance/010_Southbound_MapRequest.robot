*** Settings ***
Documentation     Test suite to determine the southbound Map-Request serving rate
Suite Setup       Prepare Environment
Suite Teardown    Destroy Environment
Library           Collections
Library           DateTime
Library           OperatingSystem
Library           RequestsLibrary
Library           String
Resource          ../../../libraries/Utils.robot
Variables         ../../../variables/Variables.py

*** Variables ***
${MAPPINGS}       10000
${LISP_SCAPY}     https://raw.githubusercontent.com/intouch/py-lispnetworking/master/lisp.py
${TOOLS_DIR}      ${CURDIR}/../../../../tools/odl-lispflowmapping-performance-tests/
${PCAP_CREATOR}    ${TOOLS_DIR}/create_map_request_pcap.py
${MAPPING_BLASTER}    ${TOOLS_DIR}/mapping_blaster.py
${REPLAY_PPS}     100000
${REPLAY_CNT}     1000
${REPLAY_FILE}    encapsulated-map-requests-sequential.pcap
${RPCS_RESULTS_FILE}    rpcs.csv
${PPS_RESULTS_FILE}    pps.csv

*** Test Cases ***
Add Simple IPv4 Mappings
    ${start_date}=    Get Current Date
    Run Process With Logging And Status Check    ${MAPPING_BLASTER}    --host    ${ODL_SYSTEM_IP}    --mappings    ${MAPPINGS}
    ${end_date}=    Get Current Date
    ${add_seconds}=    Subtract Date From Date    ${end_date}    ${start_date}
    Log    ${add_seconds}
    Set Suite Variable    ${add_seconds}

Generate Test Traffic
    Reset Stats
    ${result}=    Run Process With Logging And Status Check    /usr/local/bin/udpreplay    --pps    ${REPLAY_PPS}    --repeat    ${REPLAY_CNT}
    ...    --host    ${ODL_SYSTEM_IP}    --port    4342    ${REPLAY_FILE}
    ${partial}=    Fetch From Left    ${result.stdout}    s =
    Log    ${partial}
    ${get_seconds}=    Fetch From Right    ${partial}    ${SPACE}
    ${get_seconds}=    Convert To Number    ${get_seconds}
    Log    ${get_seconds}
    Set Suite Variable    ${get_seconds}

Compute And Export Results
    ${rpcs}=    Evaluate    ${MAPPINGS}/${add_seconds}
    Log    ${rpcs}
    Create File    ${RPCS_RESULTS_FILE}    store/s\n
    Append To File    ${RPCS_RESULTS_FILE}    ${rpcs}\n
    ${txmrep}=    Get Transmitted Map-Requests Stats
    ${pps}=    Evaluate    ${txmrep}/${get_seconds}
    Log    ${pps}
    Create File    ${PPS_RESULTS_FILE}    replies/s\n
    Append To File    ${PPS_RESULTS_FILE}    ${pps}\n

*** Keywords ***
Reset Stats
    ${resp}=    RequestsLibrary.Post    session    ${LFM_SB_RPC_API}:reset-stats
    Log    ${resp.content}
    Should Be Equal As Strings    ${resp.status_code}    200

Get Transmitted Map-Requests Stats
    ${resp}=    RequestsLibrary.Post    session    ${LFM_SB_RPC_API}:get-stats
    Log    ${resp.content}
    ${output}=    Get From Dictionary    ${resp.json()}    output
    ${stats}=    Get From Dictionary    ${output}    control-message-stats
    ${ctrlmsg}=    Get From Dictionary    ${stats}    control-message
    ${replies}=    Get From List    ${ctrlmsg}    2
    ${txmrep}=    Get From Dictionary    ${replies}    tx-count
    ${txmrep}=    Convert To Integer    ${txmrep}
    Log    ${txmrep}
    [Return]    ${txmrep}

Prepare Environment
    Create Session    session    http://${ODL_SYSTEM_IP}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS}
    Run Process With Logging And Status Check    wget    -P    ${TOOLS_DIR}    ${LISP_SCAPY}
    Run Process With Logging And Status Check    ${PCAP_CREATOR}    --requests    ${MAPPINGS}

Destroy Environment
    Delete All Sessions
    Remove File    ${TOOLS_DIR}/lisp.py*
    Remove File    ${REPLAY_FILE}
