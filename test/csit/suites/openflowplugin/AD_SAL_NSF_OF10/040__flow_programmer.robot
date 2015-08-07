*** Settings ***
Documentation     Test suite for Flow Programmer
Suite Setup       Create Session    session    http://${CONTROLLER}:${RESTPORT}    auth=${AUTH}    headers=${HEADERS}
Suite Teardown    Delete All Sessions
Library           Collections
Library           ../../../libraries/RequestsLibrary.py
Library           ../../../libraries/Common.py
Variables         ../../../variables/Variables.py
Resource          ../../../libraries/Utils.robot

*** Variables ***
${name}           flow1
${key}            flowConfig
${node_id}        00:00:00:00:00:00:00:02
${REST_CONTEXT}    /controller/nb/v2/flowprogrammer
${REST_CONTEXT_ST}    /controller/nb/v2/statistics

*** Test Cases ***
Add a flow
    [Documentation]    Add a flow, list to validate the result.
    [Tags]    adsal
    ${node}    Create Dictionary    type=OF    id=${node_id}
    ${actions}    Create List    OUTPUT=1
    ${body}    Create Dictionary    name=${name}    installInHw=true    node=${node}
    ...    priority=1    etherType=0x800    nwDst=10.0.0.1/32    actions=${actions}
    ${resp}    RequestsLibrary.Put    session    ${REST_CONTEXT}/${CONTAINER}/node/OF/${node_id}/staticFlow/${name}    data=${body}
    Should Be Equal As Strings    ${resp.status_code}    201
    ${resp}    RequestsLibrary.Get    session    ${REST_CONTEXT}/${CONTAINER}
    Should Be Equal As Strings    ${resp.status_code}    200
    ${result}    To JSON    ${resp.content}
    ${content}    Get From Dictionary    ${result}    ${key}
    List Should Contain Value    ${content}    ${body}

Check flow in flow stats
    [Documentation]    Show flow stats and validate result
    [Tags]    adsal
    ${elements}=    Create List    10.0.0.1
    Wait Until Keyword Succeeds    90s    2s    Check For Elements At URI    ${REST_CONTEXT_ST}/${CONTAINER}/flow    ${elements}

Remove a flow
    [Documentation]    Remove a flow, list to validate the result.
    [Tags]    adsal
    ${node}    Create Dictionary    type=OF    id=${node_id}
    ${actions}    Create List    OUTPUT=1
    ${body}    Create Dictionary    name=${name}    installInHw=true    node=${node}
    ...    priority=1    etherType=0x800    nwDst=10.0.0.1/32    actions=${actions}
    ${resp}    RequestsLibrary.Delete    session    ${REST_CONTEXT}/${CONTAINER}/node/OF/${node_id}/staticFlow/${name}
    Should Be Equal As Strings    ${resp.status_code}    204
    ${resp}    RequestsLibrary.Get    session    ${REST_CONTEXT}/${CONTAINER}
    Should Be Equal As Strings    ${resp.status_code}    200
    ${result}    To JSON    ${resp.content}
    ${content}    Get From Dictionary    ${result}    ${key}
    List Should Not Contain Value    ${content}    ${body}

Check flow is not in flow stats
    [Documentation]    Show flow stats and validate result
    [Tags]    adsal
    ${elements}=    Create List    10.0.0.1
    Wait Until Keyword Succeeds    60s    2s    Check For Elements Not At URI    ${REST_CONTEXT_ST}/${CONTAINER}/flow    ${elements}
