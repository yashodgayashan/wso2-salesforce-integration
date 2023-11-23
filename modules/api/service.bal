// Copyright (c) 2023, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http; 
import ballerina/mime;

import wso2_salesforce_integration.config;
import wso2_salesforce_integration.models;
import wso2_salesforce_integration.utils;

public function createSubOrganizationAdmin(models:SalesforcePayload payload) returns 
    http:Response|http:Created|http:InternalServerError|http:BadRequest {

    // Get the access token.
    string|error accessToken = getAccessToken();
    if accessToken is error {
        return <http:InternalServerError> {body: "Error while getting access token."};
    }

    // Check if the organization name is available.
    boolean|error isOrgNameAvailable = isOrganizationNameAvailable(payload.orgName, <string>accessToken);
    if isOrgNameAvailable is error {
        return <http:InternalServerError> {body: "Error while checking organization name availability."};
    }
    if (!isOrgNameAvailable) {
        return <http:BadRequest> {body: "Organization name is not available."};
    }

    // Creaet a sub organization.
    string|error subOrganizationId = createOrganization(payload.orgName, <string>accessToken);
    if subOrganizationId is error {
        return <http:InternalServerError> {body: "Error while creating sub organization."};
    } 
    
    // Get sub organization token.
    string|error subOrganizationToken = getSubOrganizationToken(accessToken, subOrganizationId);
    if subOrganizationToken is error {
        return <http:InternalServerError> {body: "Error while getting sub organization token."};
    }

    // Get admin role id.
    string|error adminRoleId = getAdminRoleId(<string>subOrganizationToken);
    if adminRoleId is error {
        return <http:InternalServerError> {body: "Error while getting admin role id."};
    }

    // Create a user in the sub organization.
    http:Response|error createUserResponse = createUser(payload, <string> adminRoleId, <string>subOrganizationToken);
    if createUserResponse is error {
        return <http:InternalServerError> {body: "Error while creating user."};
    }
    return createUserResponse;

    // // Assign user to admin role.
    // http:Response|error assignUserToAdminRoleResponse = assignUserToAdminRole(
    //     payload.username, <string>adminRoleId, <string>subOrganizationToken);
    // if assignUserToAdminRoleResponse is error {
    //     return <http:InternalServerError> {body: "Error while assigning user to admin role."};
    // }
    // if (assignUserToAdminRoleResponse.statusCode != 200) {
    //     return assignUserToAdminRoleResponse;
    // }

    // return <http:Created> {body: "Sub organization admin created successfully."};
}

// Get access token from the token endpoint.
function getAccessToken() returns string|error {

    http:Client clientTokenEndpoint = check new (
        config:tokenEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    json tokenResponse = check clientTokenEndpoint->post(
        "",
        {
        "grant_type": "client_credentials",
        "scope": "SYSTEM"
    },
    {
        "Authorization": string `Basic ${utils:getBasicAuth()}`
    },
        mime:APPLICATION_FORM_URLENCODED
    );
    
    return <string> check tokenResponse.access_token;
}

// Check if the organization name is available.
function isOrganizationNameAvailable(string organizationName, string accessToken) returns boolean|error {

    http:Client checkOrganizationNameEndpoint = check new (
        config:organizationEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    json organizationNameAvailabilityResponse = check checkOrganizationNameEndpoint->post(
            "/check-name",
        {
            "name": organizationName
        },
        {
            "Authorization": string `Bearer ${accessToken}`
        },
            mime:APPLICATION_JSON
    );

    return <boolean> check organizationNameAvailabilityResponse.available;
}

// Create a sub organization.
function createOrganization(string organizationName, string accessToken) returns string|error {

    http:Client createSubOrganizationEndpoint = check new (
        config:organizationEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    http:Response response = check createSubOrganizationEndpoint->post(
        "",
        {
            "name": organizationName
        },
        {
            "Authorization": string `Bearer ${accessToken}`
        },
        mime:APPLICATION_JSON
    );

    if (response.statusCode != 201) {
        return error ("Error while creating sub organization.");
    }

    // Process successful response.
    json subOrgCreationResponseBody = check response.getJsonPayload();
    json subOrgIdJson = check subOrgCreationResponseBody.id;
    return subOrgIdJson.toString();
}

// Get a token for sub organization.
function getSubOrganizationToken(string accessToken, string subOrganizationId) returns string|error {

    http:Client clientTokenEndpoint = check new (
        config:tokenEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    json tokenResponse = check clientTokenEndpoint->post(
        "",
        {
            "grant_type": "organization_switch_cc",
            "scope": "SYSTEM",
            "token": accessToken,
            "switching_organization": subOrganizationId
        },
        {
            "Authorization": string `Basic ${utils:getBasicAuth()}`
        },
        mime:APPLICATION_FORM_URLENCODED
    );

    return <string> check tokenResponse.access_token;
}

// Get the admin role id.
function getAdminRoleId(string subOrgAccessToken) returns string|error {

    http:Client getAdminRoleIdEndpoint = check new (
        config:scimEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    json adminRoleIdResponse = check getAdminRoleIdEndpoint->get(
        "/v2/Roles?filter=displayName%20eq%20admin",
        {
            "Authorization": string `Bearer ${subOrgAccessToken}`
        }
    );

    json resources = check adminRoleIdResponse.Resources; 
    json[] resourcesArray = <json[]> resources;
    if (resourcesArray.length() > 0) {
        json adminRole = resourcesArray[0];
        json adminRoleId = check adminRole.id;
        return adminRoleId.toString();
    } else {
       return error ("Error while getting admin role id.");
    }
}

// Create a user in the sub organization. 
function createUser(models:SalesforcePayload salesForcePayload, string adminRoleId, string subOrgAccessToken) 
    returns http:Response|error {

    http:Client scimEndpoint = check new (
        config:scimEndpoint, 
        httpVersion = http:HTTP_1_1, 
        secureSocket = {
            cert: {
                path: config:TRUSTSTORE_PATH,
                password: config:TRUSTSTORE_PASSWORD
            }
        }
    );

    json userCreation = {
        "method": "POST",
        "bulkId": "userCreation:1",
        "path": "/Users",
        "data": {
            "schemas": [
            "urn:ietf:params:scim:schemas:core:2.0:User",
            "urn:scim:wso2:schema"
            ],
            "name": {
                "familyName": salesForcePayload.firstName,
                "givenName": salesForcePayload.lastName
            },
            "userName": salesForcePayload.username,
            "emails": [
                {
                    "primary": true,
                    "value": salesForcePayload.email
                }
            ],
            "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User": {"askPassword": true}
        }
    };

    json roleAssignment = {  
        "method":"PATCH",
        "path": string `/v2/Roles/${adminRoleId}`,
        "data":{
            "Operations":[
                {
                    "op":"add",
                    "value": {
                        "users":[
                            {
                                "value": "bulkId:userCreation:1"
                            }
                        ]
                    }
                }
            ]
        }
    };

    json requestBody = {
        "schemas": [
            "urn:ietf:params:scim:api:messages:2.0:BulkRequest"
        ],
        "Operations": [
            userCreation,
            roleAssignment
        ]
    };

    return check scimEndpoint->post(
        "/Bulk",
        requestBody,
        {
            "Authorization": string `Bearer ${subOrgAccessToken}`
        },
        mime:APPLICATION_JSON
    );
}

// // Assign user to admin role.
// function assignUserToAdminRole(string userId, string adminRoleId, string subOrgAccessToken) returns http:Response|error {

//     http:Client assignUserToAdminRoleEndpoint = check new (
//         config:scimEndpoint, 
//         httpVersion = http:HTTP_1_1, 
//         secureSocket = {
//             cert: {
//                 path: config:TRUSTSTORE_PATH,
//                 password: config:TRUSTSTORE_PASSWORD
//             }
//         }
//     );

//     json requestBody = {
//         "Operations": [
//             {
//                 "op": "add",
//                 "value": {
//                     "users": [
//                         {
//                             "value": string `${userId}`
//                         }
//                     ]
//                 }
//             }
//         ]
//     };
//     return check assignUserToAdminRoleEndpoint->patch(
//         "/v2/Roles/" + adminRoleId,
//         requestBody,
//         {
//             "Authorization": string `Bearer ${subOrgAccessToken}`
//         },
//         mime:APPLICATION_JSON
//     );
// }
