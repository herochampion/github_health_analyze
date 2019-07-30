WITH
  data AS (
  SELECT
    type,
    CASE
      WHEN type IN ('ReleaseEvent',  'PullRequestEvent',  'PullRequestReviewCommentEvent',  'IssuesEvent') THEN JSON_EXTRACT_SCALAR(payload,  '$.action')
  END
    AS action,
    CASE
      WHEN type IN ('PullRequestEvent',  'PullRequestReviewCommentEvent') THEN JSON_EXTRACT_SCALAR(payload,  '$.pull_request.id')
  END
    AS pull_id,
    CASE
      WHEN type IN ('PullRequestEvent') THEN JSON_EXTRACT_SCALAR(payload,  '$.pull_request.merged')
  END
    AS merge_status,
    CASE
      WHEN type IN ('IssuesEvent') THEN JSON_EXTRACT_SCALAR(payload,  '$.issue.id')
  END
    AS issue_id,
    repo.name AS repo_name,
    org.login AS org_login,
    actor.login AS actor_login,
    created_at
  FROM
    `githubarchive.day.2019*`
  WHERE
    type IN ('PullRequestEvent',
      'PushEvent',
      'PullRequestReviewCommentEvent',
      'ReleaseEvent',
      'IssuesEvent')
    AND _TABLE_SUFFIX BETWEEN FORMAT_DATE('%m%d', DATE_ADD(CURRENT_DATE(), INTERVAL -30 day))
    AND FORMAT_DATE('%m%d', CURRENT_DATE()))
SELECT
  repo_name,
  org_login,
  num_comits,
  (commit_score+first_merged_score+issue_remained_score+ratio_issue_score+issue_response_score)/5 as health_score,
  num_release,
  pull_avg_comment,
  commit_score
  first_merged_score,
  issue_remained_score,
  ratio_issue_score,
  issue_response_score
  
FROM ((
    SELECT
      repo_name,
      org_login
    FROM
      data
    GROUP BY
      repo_name,
      org_login) a 
/*
NUMBER OF COMMITS AND COMMITS_SCORE
*/
  LEFT JOIN (
    SELECT
      repo_name AS repo_name_commit,
      org_login AS org_login_commit,
      SUM(num_commit_per_day) num_comits,
      AVG(num_commit_per_day)/MAX(num_commit_per_day) AS commit_score
    FROM (
      SELECT
        repo_name,
        org_login,
        DATE(created_at) AS DAY,
        COUNT(*) AS num_commit_per_day
      FROM
        data
      WHERE
        type ='PushEvent'
      GROUP BY
        org_login,
        repo_name,
        DAY )
    GROUP BY
      repo_name_commit,
      org_login_commit) commit
  ON
    a.repo_name = commit.repo_name_commit
    AND a.org_login = commit.org_login_commit
/*
NUMBER OF RELEASES
*/
  LEFT JOIN (
    SELECT
      repo_name AS repo_name_release,
      org_login AS org_login_release,
      COUNT(*) AS num_release
    FROM
      data
    WHERE
      type ='ReleaseEvent'
    GROUP BY
      repo_name_release,
      org_login_release ) release
  ON
    a.repo_name = release.repo_name_release
    AND a.org_login = release.org_login_release 
/*
Average time for a pull request to get merged
*/
  LEFT JOIN (
    SELECT
      repo_name_pull,
      org_login_pull,
      CASE
        WHEN MAX(TIMESTAMP_DIFF(closed_time_pull,open_time_pull, HOUR)) =0 THEN 0
      ELSE
      AVG(TIMESTAMP_DIFF(closed_time_pull,open_time_pull, HOUR))/(MAX(TIMESTAMP_DIFF(closed_time_pull,open_time_pull, HOUR)))
    END
      AS first_merged_score
    FROM (
      SELECT
        repo_name AS repo_name_pull,
        org_login AS org_login_pull,
        pull_id,
        MAX(CASE
            WHEN action = 'opened' THEN created_at
          ELSE
          TIMESTAMP_ADD(CURRENT_TIMESTAMP(),INTERVAL -30 DAY)
        END
          ) AS open_time_pull,
        MAX(CASE
            WHEN merge_status='true' AND action='closed' THEN created_at
          ELSE
          CURRENT_TIMESTAMP()
        END
          ) closed_time_pull
      FROM
        data
      WHERE
        type = 'PullRequestEvent'
        AND action IN ('opened',
          'closed')
      GROUP BY
        repo_name_pull,
        org_login_pull,
        pull_id )
    GROUP BY
      repo_name_pull,
      org_login_pull ) first_pull
  ON
    a.repo_name = first_pull.repo_name_pull
    AND a.org_login = first_pull.org_login_pull )
 
/*
Average time that an issue remains opened
*/

LEFT JOIN (
  SELECT
    repo_name AS repo_name_issue,
    org_login AS org_login_issue,
    CASE
      WHEN AVG(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR)) = 0 THEN 0
    ELSE
    MIN(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR))/AVG(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR))
  END
    AS issue_remained_score
  FROM (
    SELECT
      repo_name,
      org_login,
      issue_id,
      MAX(CASE
          WHEN action = 'opened' THEN created_at
        ELSE
        TIMESTAMP_ADD(CURRENT_TIMESTAMP(),INTERVAL -30 DAY)
      END
        ) AS open_time_issue,
      MAX(CASE
          WHEN action = 'closed' THEN created_at
        ELSE
        CURRENT_TIMESTAMP()
      END
        ) AS close_time_issue
    FROM
      data
    WHERE
      type = 'IssuesEvent'
      and action in ('opened','closed')
    GROUP BY
      repo_name,
      org_login,
      issue_id )
  GROUP BY
    repo_name_issue,
    org_login_issue) issue_remain
ON
  a.repo_name = issue_remain.repo_name_issue
  AND a.org_login = issue_remain.org_login_issue
  
/*
Ratio of closed to open issues
*/
  
LEFT JOIN (
  SELECT
    repo_name_issue_ratio,
    org_login_issue_ratio,
    CASE
      WHEN COUNT(CASE
        WHEN issue_count > 1 THEN 1
    END
      ) = 0 THEN 0
    ELSE
    COUNT(CASE
        WHEN issue_count > 2 THEN 1
    END
      )/COUNT(CASE
        WHEN issue_count > 1 THEN 1
    END
      )
  END
    AS ratio_issue_score
  FROM (
    SELECT
      repo_name AS repo_name_issue_ratio,
      org_login AS org_login_issue_ratio,
      issue_id,
      COUNT(CASE
          WHEN action ='opened' THEN 2
          WHEN action ='closed' THEN 1
        ELSE
        0
      END
        ) AS issue_count
    FROM
      data
    WHERE
      type = 'IssuesEvent'
    GROUP BY
      repo_name_issue_ratio,
      org_login_issue_ratio,
      issue_id)
  GROUP BY
    repo_name_issue_ratio,
    org_login_issue_ratio) ratio_issue
ON
  a.repo_name = ratio_issue.repo_name_issue_ratio
  AND a.org_login = ratio_issue.org_login_issue_ratio
/*
Average number of comments per pull requests
*/


LEFT JOIN (
  SELECT
    repo_name_comment,
    org_login_comment,
    AVG(comment_count) pull_avg_comment
  FROM (
    SELECT
      repo_name AS repo_name_comment,
      org_login AS org_login_comment,
      pull_id,
      COUNT(
        CASE
          WHEN action='created' THEN 1
        ELSE
        0
      END
        ) AS comment_count
    FROM
      data
    WHERE
      type = 'PullRequestReviewCommentEvent'
    GROUP BY
      repo_name_comment,
      org_login_comment,
      pull_id)
  GROUP BY
    repo_name_comment,
    org_login_comment) pull_comment
ON
  a.repo_name = pull_comment.repo_name_comment
  AND a.org_login = pull_comment.org_login_comment
  
 /*
 Average response time of first response to an issue
 */
 LEFT JOIN (
  SELECT
    repo_name AS repo_name_issue_res,
    org_login AS org_login_issue_res,
    CASE
      WHEN AVG(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR)) = 0 THEN 0
    ELSE
    MIN(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR))/AVG(TIMESTAMP_DIFF(close_time_issue,open_time_issue, HOUR))
  END
    AS issue_response_score
  FROM (
    SELECT
      repo_name,
      org_login,
      issue_id,
      MAX(CASE
          WHEN action = 'opened' THEN created_at
        ELSE
        Null
      END
        ) AS open_time_issue,
      MIN(CASE
          WHEN action != 'opened' THEN created_at
        ELSE
        CURRENT_TIMESTAMP()
      END
        ) AS close_time_issue
    FROM
      data
    WHERE
      type = 'IssuesEvent'
    GROUP BY
      repo_name,
      org_login,
      issue_id )
  GROUP BY
    repo_name_issue_res,
    org_login_issue_res) issue_response
ON
  a.repo_name = issue_response.repo_name_issue_res
  AND a.org_login = issue_response.org_login_issue_res
ORDER BY
  health_score DESC
LIMIT 1000
