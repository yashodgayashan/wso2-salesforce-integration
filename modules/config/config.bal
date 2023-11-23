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

public configurable string baseUrl = "https://is.wso2isdemo.com";
public configurable string tenantDomain = "carbon.super";
public configurable string applicationRoleName = "Administrator";
public configurable string b2bAppClientID = ?;
public configurable string b2bAppClientSecret = ?;

// Endpoints.
public string tokenEndpoint =  baseUrl + "/oauth2/token";
public string organizationEndpoint = baseUrl + "/api/server/v1/organizations";
public string scimEndpoint = baseUrl + "/t/" + tenantDomain + "/o/scim2";
public string createUserEndpoint = baseUrl + "/t/" + tenantDomain + "/o/scim2/Users";
public string adminRoleIdEndpoint = baseUrl + "/t/" + tenantDomain + "/o/scim2/v2/Roles?filter=name%20eq%20admin";
public string assignAdminRole = baseUrl + "/t/" + tenantDomain + "/o/scim2/v2/Roles/{admin-role-id}";


