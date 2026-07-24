/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckContext {
  public Id recordId;
  public String objectApiName;
  public SObject record;
  public Map<String, Object> parameters; // parsed from ApexParametersJson__c; empty map when blank
  public String ruleDeveloperName;
}
