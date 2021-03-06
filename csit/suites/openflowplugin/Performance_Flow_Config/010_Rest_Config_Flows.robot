*** Settings ***
Documentation     Test suite with connection of multiple switches
Suite Setup       Start Suite
Suite Teardown    Stop Suite
Library           OperatingSystem
Library           Collections
Library           XML
Library           Process
Variables         ../../../variables/Variables.py
Library           RequestsLibrary
Library           ../../../libraries/Common.py
Library           SSHLibrary

*** Variables ***
${switches}       25
${flows}          2000
${threads}        5
${start}          sudo mn --controller=remote,ip=${ODL_SYSTEM_IP} --topo linear,${switches},1 --switch ovsk,protocols=OpenFlow13
${PERFSCRIPT}     ${CURDIR}/../../../../tools/odl-mdsal-clustering-tests/clustering-performance-test/flow_add_delete_test.py
${PARSESCRIPT}    ${CURDIR}/../../../../tools/odl-mdsal-clustering-tests/clustering-performance-test/create_plot_data_files.py

*** Test Cases ***
Are Switches Connected
    [Documentation]    Checks wheather switches are connected to controller
    [Setup]    Start Http Session
    ${resp}=    Get    tcsession    /restconf/operational/network-topology:network-topology/topology/flow:1    headers=${ACCEPT_XML}
    Log    ${resp.content}
    ${count}=    Get Element Count    ${resp.content}    xpath=node
    Should Be Equal As Numbers    ${count}    ${switches}
    [Teardown]    Stop Http Session

Configure And Deconfigure Flows
    ${result}=    Run Process    ${PERFSCRIPT}    --host    ${ODL_SYSTEM_IP}    --flows    ${flows}
    ...    --threads    ${threads}    --auth    shell=yes
    Log    ${result.stdout}
    Create File    out.log.txt    content=${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${result}=    Run Process    python    ${PARSESCRIPT}

*** Keywords ***
Start Suite
    [Documentation]    Basic setup/cleanup work that can be done safely before any system
    ...    is run.
    Log    Start the test on the base edition
    ${mininet_conn_id}=    Open Connection    ${TOOLS_SYSTEM_IP}    prompt=>    timeout=600s
    Set Suite Variable    ${mininet_conn_id}
    Login With Public Key    ${TOOLS_SYSTEM_USER}    ${USER_HOME}/.ssh/${SSH_KEY}    any
    Write    sudo ovs-vsctl set-manager ptcp:6644
    Read Until    >
    Write    sudo mn -c
    Read Until    >
    Read Until    >
    Read Until    >
    Write    ${start}
    Read Until    mininet>
    Sleep    6

Stop Suite
    [Documentation]    Cleanup/Shutdown work that should be done at the completion of all
    ...    tests
    Log    Stop the test on the base edition
    Switch Connection    ${mininet_conn_id}
    Read
    Write    exit
    Read Until    >
    Close Connection

Start Http Session
    [Documentation]    Starts http session
    Log    http://${ODL_SYSTEM_IP}:${RESTCONFPORT} auth=${AUTH} headers=${HEADERS_XML}
    Create Session    tcsession    http://${ODL_SYSTEM_IP}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS_XML}

Stop Http Session
    [Documentation]    Stops http session
    Delete All Sessions
