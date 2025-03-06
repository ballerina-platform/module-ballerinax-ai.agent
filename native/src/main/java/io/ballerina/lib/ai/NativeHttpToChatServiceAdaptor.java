/*
 * Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.ai;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.concurrent.CompletableFuture;

import static io.ballerina.runtime.api.utils.StringUtils.fromString;

public class NativeHttpToChatServiceAdaptor {
    public static Object invokeOnChatMessageFunction(Environment env, BMap<BString, Object> message,
                                                     BString eventFunction, BObject serviceObj) {
        Object[] args = new Object[]{message, true};
        return env.yieldAndRun(() -> {
            CompletableFuture<Object> balFuture = new CompletableFuture<>();
            try {
                Object result = env.getRuntime().callMethod(serviceObj, eventFunction.getValue(), null, args);
                Utils.notifySuccess(balFuture, result);
                return Utils.getResult(balFuture);
            } catch (BError bError) {
                BString errorMessage = fromString("service method invocation failed: " + bError.getErrorMessage());
                return ErrorCreator.createError(errorMessage, bError);
            }
        });
    }
}
