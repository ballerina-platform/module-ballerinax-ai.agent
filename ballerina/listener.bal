// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

# Description.
public class Listener {
    private http:Listener httpListener;
    private DispatcherService dispatcherService;

    public function init(int|http:Listener listenOn = 8090) returns error? {
        if listenOn is http:Listener {
            self.httpListener = listenOn;
        } else {
            self.httpListener = check new (listenOn);
        }
        self.dispatcherService = new DispatcherService();
    }
    public isolated function attach(ChatService chatService, string[]|string? name = ()) returns error? {
        check self.httpListener.attach(self.dispatcherService, name);
        self.dispatcherService.addServiceRef(chatService);
    }

    public isolated function detach(ChatService chatService) returns error? {
        check self.httpListener.detach(self.dispatcherService);
        self.dispatcherService.removeServiceRef();
    }

    public isolated function 'start() returns error? {
        check self.httpListener.start();
    }

    public isolated function gracefulStop() returns error? {
        check self.httpListener.gracefulStop();
    }

    public isolated function immediateStop() returns error? {
        check self.httpListener.immediateStop();
    }
}
