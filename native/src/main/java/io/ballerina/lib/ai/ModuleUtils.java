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
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BError;

public final class ModuleUtils {
    private static final String PACKAGE_ORG = "ballerinax";
    private static final String PACKAGE_NAME = "ai.agent";

    private static Module module;

    private ModuleUtils() {
    }

    @SuppressWarnings("unused")
    public static Module getModule() {
        return module;
    }

    @SuppressWarnings("unused")
    public static void setModule(Environment env) {
        module = env.getCurrentModule();
    }

    static boolean isModuleDefinedError(BError error) {
        Type errorType = error.getType();
        Module packageDetails = errorType.getPackage();
        String orgName = packageDetails.getOrg();
        String packageName = packageDetails.getName();
        return PACKAGE_ORG.equals(orgName) && PACKAGE_NAME.equals(packageName);
    }
}
