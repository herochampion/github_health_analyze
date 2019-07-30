package com.quod.ai;

import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryOptions;
import com.google.cloud.bigquery.FieldValueList;
import com.google.cloud.bigquery.Job;
import com.google.cloud.bigquery.JobId;
import com.google.cloud.bigquery.JobInfo;
import com.google.cloud.bigquery.QueryJobConfiguration;
import com.google.cloud.bigquery.QueryResponse;
import com.google.cloud.bigquery.TableResult;
import java.util.UUID;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
public class App {
  public static void main(String[] args) throws Exception {
	System.out.println("THIS PROGRAM WILL PRINT OUT 1000 LIVE HEALTHIEST REPOS IN THE LAST 30 DAYS");
	System.out.println("========== YOU WILL SEE ========");
	System.out.println("repo_name,org_login,health_score");
    BigQuery bigquery = BigQueryOptions.getDefaultInstance().getService();
    QueryJobConfiguration queryConfig =
        QueryJobConfiguration.newBuilder(readSQLfile(args[0]))

            .setUseLegacySql(false)
            .build();

    // Create a job ID so that we can safely retry.
    JobId jobId = JobId.of(UUID.randomUUID().toString());
    Job queryJob = bigquery.create(JobInfo.newBuilder(queryConfig).setJobId(jobId).build());

    // Wait for the query to complete.
    queryJob = queryJob.waitFor();

    // Check for errors
    if (queryJob == null) {
      throw new RuntimeException("Job no longer exists");
    } else if (queryJob.getStatus().getError() != null) {
      // You can also look at queryJob.getStatus().getExecutionErrors() for all
      // errors, not just the latest one.
      throw new RuntimeException(queryJob.getStatus().getError().toString());
    }

    // Get the results.
    TableResult result = queryJob.getQueryResults();
	System.out.println("Done Querying ...");
    // Print all pages of the results.
    for (FieldValueList row : result.iterateAll()) {
      String repo_name = row.get("repo_name").getStringValue();
	  String org_login = row.get("org_login").getStringValue();
	  String health_score = row.get("health_score").getStringValue();
	  System.out.printf("%s,%s,%s \n",repo_name,org_login,health_score);
    }
  }
  
  private static String readSQLfile(String filePath)
    {
        String content = "";
 
        try
        {
            content = new String ( Files.readAllBytes( Paths.get(filePath) ) );
        }
        catch (IOException e)
        {
            e.printStackTrace();
        }
 
        return content;
    }
}



