defmodule DiwaAgent.Tools.Definitions do
  @moduledoc """
  Tool definitions for the Diwa MCP server.

  Defines all available tools with their schemas and metadata.
  """

  @doc """
  Get all tool definitions.
  """
  def all_tools do
    [
      # Context Management Tools
      create_context(),
      list_contexts(),
      get_context(),
      list_organizations(),
      get_context_health(),
      run_context_scan(),
      list_conflicts(),
      resolve_conflict(),
      update_context(),
      delete_context(),

      # Memory Management Tools
      add_memory(),
      add_memories(),
      list_memories(),
      get_memory(),
      update_memory(),
      delete_memory(),

      # Search Tools
      search_memories(),

      # Bridge Coordination Tools
      set_project_status(),
      get_project_status(),
      add_requirement(),
      mark_requirement_complete(),
      record_lesson(),
      search_lessons(),
      flag_blocker(),
      resolve_blocker(),
      set_handoff_note(),
      get_active_handoff(),
      get_pending_tasks(),
      get_resume_context(),
      log_progress(),

      # SDLC Lifecycle Tools
      record_decision(),
      record_deployment(),
      log_incident(),
      record_pattern(),
      record_review(),
      prioritize_requirement(),
      list_by_tag(),
      export_context(),
      perform_backup(),
      record_analysis_result(),
      link_memories(),
      get_memory_tree(),
      
      # Agent Coordination (Phase 1.4)
      register_agent(),
      poll_delegated_tasks(),
      delegate_task(),
      respond_to_delegation(),
      complete_delegation(),

      # SINAG Lifecycle Tools (Phase 3.2)
      get_agent_health(),
      restore_agent(),
      log_failure(),
      purge_old_checkpoints(),

      # Ledger and Rollback Tools (Phase 3.1)
      get_memory_history(),
      rollback_memory(),
      compare_memory_versions(),
      get_recent_changes(),

      # Distributed Consensus Tools (Phase 3)
      arbitrate_conflict(),
      get_cluster_status(),
      get_byzantine_nodes(),

      # Shortcut Interpreter Tools (Phase 4)
      execute_shortcut(),
      list_shortcuts(),
      register_shortcut_alias(),

      # Advanced Bridge Tools (Module 2-7)
      classify_memory(),
      ingest_context(),
      start_session(),
      log_session_activity(),
      end_session(),
      hydrate_context(),
      validate_action(),
      prune_expired_memories()
    ]
  end

  defp create_context do
    %{
      name: "create_context",
      description: "Create a new context (project/workspace) to organize memories",
      inputSchema: %{
        type: "object",
        properties: %{
          name: %{
            type: "string",
            description: "Name of the context (e.g., 'My Project', 'API Development')"
          },
          description: %{
            type: "string",
            description: "Optional description of what this context is for"
          },
          organization_id: %{
            type: "string",
            description: "UUID of the organization to create the context in"
          }
        },
        required: ["name"]
      }
    }
  end

  defp list_contexts do
    %{
      name: "list_contexts",
      description: "List all available contexts for an organization",
      inputSchema: %{
        type: "object",
        properties: %{
          organization_id: %{
            type: "string",
            description: "Filter contexts by organization UUID"
          }
        }
      }
    }
  end

  defp list_organizations do
    %{
      name: "list_organizations",
      description: "List all organizations (Multi-Tenancy)",
      inputSchema: %{
        type: "object",
        properties: %{}
      }
    }
  end

  defp get_context do
    %{
      name: "get_context",
      description: "Get detailed information about a specific context",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context to retrieve"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp update_context do
    %{
      name: "update_context",
      description: "Update a context's name or description",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context to update"
          },
          name: %{
            type: "string",
            description: "New name for the context"
          },
          description: %{
            type: "string",
            description: "New description for the context"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp delete_context do
    %{
      name: "delete_context",
      description: "Delete a context and all its memories (cannot be undone)",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context to delete"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp add_memory do
    %{
      name: "add_memory",
      description:
        "Add a new memory/note to a context. Use this to store any information: decisions, notes, code snippets, lessons learned, or observations.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context to add the memory to"
          },
          content: %{
            type: "string",
            description: "The memory content (can be notes, code snippets, decisions, etc.)"
          },
          metadata: %{
            type: "string",
            description: "Optional metadata in JSON format"
          },
          actor: %{
            type: "string",
            description:
              "Who is creating this (human, claude, antigravity, cursor, ci, monitoring, scanning, automation)"
          },
          project: %{
            type: "string",
            description: "Optional project workspace name or ID"
          },
          tags: %{
            type: "string",
            description: "Comma-separated tags or JSON array"
          },
          parent_id: %{
            type: "string",
            description: "Optional ID of a parent memory this relates to"
          },
          external_ref: %{
            type: "string",
            description: "Optional URL or reference to external systems (GitHub, JIRA)"
          },
          severity: %{
            type: "string",
            description: "Optional severity level (information, low, moderate, high, critical)"
          }
        },
        required: ["context_id", "content"]
      }
    }
  end

  defp add_memories do
    %{
      name: "add_memories",
      description: "Batch add multiple memories to a context",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context to add the memories to"
          },
          memories: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                content: %{type: "string"},
                metadata: %{type: "string"},
                actor: %{type: "string"},
                project: %{type: "string"},
                tags: %{type: "string"},
                parent_id: %{type: "string"},
                external_ref: %{type: "string"},
                severity: %{type: "string"}
              },
              required: ["content"]
            },
            description: "List of memories to add"
          }
        },
        required: ["context_id", "memories"]
      }
    }
  end

  defp list_memories do
    %{
      name: "list_memories",
      description: "List all memories in a context",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "ID of the context whose memories to list"
          },
          limit: %{
            type: "integer",
            description: "Maximum number of memories to return (default: 100)"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp get_memory do
    %{
      name: "get_memory",
      description: "Get a specific memory by its ID",
      inputSchema: %{
        type: "object",
        properties: %{
          memory_id: %{
            type: "string",
            description: "ID of the memory to retrieve"
          }
        },
        required: ["memory_id"]
      }
    }
  end

  defp update_memory do
    %{
      name: "update_memory",
      description: "Update the content of a memory",
      inputSchema: %{
        type: "object",
        properties: %{
          memory_id: %{
            type: "string",
            description: "ID of the memory to update"
          },
          content: %{
            type: "string",
            description: "New content for the memory"
          }
        },
        required: ["memory_id", "content"]
      }
    }
  end

  defp delete_memory do
    %{
      name: "delete_memory",
      description: "Delete a specific memory (cannot be undone)",
      inputSchema: %{
        type: "object",
        properties: %{
          memory_id: %{
            type: "string",
            description: "ID of the memory to delete"
          }
        },
        required: ["memory_id"]
      }
    }
  end

  defp search_memories do
    %{
      name: "search_memories",
      description:
        "Search for memories containing specific text. Can search across all contexts or limit to a specific context.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Text to search for (case-insensitive partial match)"
          },
          context_id: %{
            type: "string",
            description: "Optional: Limit search to memories in this specific context only"
          }
        },
        required: ["query"]
      }
    }
  end

  # --- Bridge Coordination Tools ---

  defp set_project_status do
    %{
      name: "set_project_status",
      description:
        "Set the overall status, phase and completion percentage of a project context.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          status: %{
            type: "string",
            description: "Current status (e.g., Planning, Implementation, Testing, Complete)"
          },
          completion_pct: %{
            type: "integer",
            description: "Percentage of project completion (0-100)"
          },
          notes: %{type: "string", description: "Brief notes on the current status"}
        },
        required: ["context_id", "status", "completion_pct"]
      }
    }
  end

  defp get_project_status do
    %{
      name: "get_project_status",
      description: "Retrieve the latest status and progress for a project context.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp add_requirement do
    %{
      name: "add_requirement",
      description: "Add a mandatory project requirement to track.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          title: %{type: "string", description: "Short title of the requirement"},
          description: %{type: "string", description: "Detailed description of what is required"},
          priority: %{
            type: "string",
            enum: ["High", "Medium", "Low"],
            description: "Importance of this requirement"
          }
        },
        required: ["context_id", "title", "description"]
      }
    }
  end

  defp mark_requirement_complete do
    %{
      name: "mark_requirement_complete",
      description: "Mark a specific project requirement as completed.",
      inputSchema: %{
        type: "object",
        properties: %{
          requirement_id: %{
            type: "string",
            description: "The UUID of the requirement (stored as a memory ID)"
          }
        },
        required: ["requirement_id"]
      }
    }
  end

  defp record_lesson do
    %{
      name: "record_lesson",
      description: "Record a technical lesson, insight, or mistake to avoid in the future.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          title: %{
            type: "string",
            description: "Title of the lesson (e.g., 'Escript NIF limitation')"
          },
          content: %{
            type: "string",
            description: "The actual insight or steps to avoid the mistake"
          },
          category: %{
            type: "string",
            description: "Category (e.g., Architecture, NIF, DevX, Protocol)"
          }
        },
        required: ["context_id", "title", "content"]
      }
    }
  end

  defp search_lessons do
    %{
      name: "search_lessons",
      description: "Global search across all contexts for recorded lessons and insights.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Text to search for in lessons"}
        },
        required: ["query"]
      }
    }
  end

  defp flag_blocker do
    %{
      name: "flag_blocker",
      description: "Flag a technical or architectural blocker that is stopping progress.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          title: %{type: "string", description: "Short summary of the blocker"},
          description: %{type: "string", description: "Detailed explanation of the blocker"},
          severity: %{
            type: "string",
            enum: ["Critical", "Moderate"],
            description: "How badly this blocker is affecting the project"
          }
        },
        required: ["context_id", "title", "description"]
      }
    }
  end

  defp resolve_blocker do
    %{
      name: "resolve_blocker",
      description: "Mark a previously flagged blocker as resolved.",
      inputSchema: %{
        type: "object",
        properties: %{
          blocker_id: %{
            type: "string",
            description: "The UUID of the blocker (stored as a memory ID)"
          },
          resolution: %{
            type: "string",
            description: "Brief summary of how the blocker was resolved"
          }
        },
        required: ["blocker_id", "resolution"]
      }
    }
  end

  defp set_handoff_note do
    %{
      name: "set_handoff_note",
      description: "Create a 'Resume Card' or handoff note for the next AI session.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          summary: %{
            type: "string",
            description: "Brief summary of what was accomplished this session"
          },
          next_steps: %{
            type: "array",
            items: %{type: "string"},
            description: "List of tactical next steps"
          },
          active_files: %{
            type: "array",
            items: %{type: "string"},
            description: "List of files that were primarily being edited"
          }
        },
        required: ["context_id", "summary", "next_steps"]
      }
    }
  end

  defp get_active_handoff do
    %{
      name: "get_active_handoff",
      description:
        "Retrieve the most recent handoff note to resume work from a previous session.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp get_pending_tasks do
    %{
      name: "get_pending_tasks",
      description: "Get pending tasks/requirements for a context, ordered by priority.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          limit: %{
            type: "integer",
            description: "Maximum number of tasks to return (default: 10)"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp get_resume_context do
    %{
      name: "get_resume_context",
      description:
        "Get comprehensive session start context including handoff note, pending tasks, recent errors, active blockers, and health score.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp log_progress do
    %{
      name: "log_progress",
      description: "Log a quick progress update or status note during work.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          message: %{type: "string", description: "Progress message or status update"},
          tags: %{type: "string", description: "Optional comma-separated tags"}
        },
        required: ["context_id", "message"]
      }
    }
  end

  defp record_decision do
    %{
      name: "record_decision",
      description:
        "Record a technical or design decision with rationale and context. Use this whenever you make an important choice about architecture, technology, patterns, or approach.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          decision: %{type: "string", description: "The decision made"},
          rationale: %{type: "string", description: "Why this decision was made"},
          alternatives: %{type: "string", description: "What other options were considered"}
        },
        required: ["context_id", "decision", "rationale"]
      }
    }
  end

  defp record_deployment do
    %{
      name: "record_deployment",
      description: "Record a deployment event.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          environment: %{type: "string", description: "Target environment (prod, staging, etc.)"},
          version: %{type: "string", description: "Version or commit SHA being deployed"},
          status: %{
            type: "string",
            description: "Result of deployment (success, failed, partial)"
          },
          external_ref: %{type: "string", description: "Link to CI/CD job or release notes"}
        },
        required: ["context_id", "environment", "version", "status"]
      }
    }
  end

  defp log_incident do
    %{
      name: "log_incident",
      description: "Log a production or development incident/error for tracking.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          title: %{type: "string", description: "Short title of the incident"},
          description: %{type: "string", description: "Detailed description of what happened"},
          severity: %{
            type: "string",
            enum: ["critical", "high", "moderate", "low"],
            description: "How bad the incident is"
          },
          external_ref: %{type: "string", description: "Link to monitoring dashboard or ticket"}
        },
        required: ["context_id", "title", "description", "severity"]
      }
    }
  end

  defp record_pattern do
    %{
      name: "record_pattern",
      description: "Record a recurring pattern, best practice, or architectural standard.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          name: %{type: "string", description: "Name of the pattern"},
          description: %{type: "string", description: "Description and usage rules"},
          example: %{type: "string", description: "Code snippet or example usage"}
        },
        required: ["context_id", "name", "description"]
      }
    }
  end

  defp record_review do
    %{
      name: "record_review",
      description: "Record a code review, architectural review, or security review.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          title: %{type: "string", description: "Title of the review"},
          summary: %{type: "string", description: "Main findings and outcomes"},
          status: %{
            type: "string",
            enum: ["approved", "changes_requested", "pending", "commented"]
          },
          external_ref: %{type: "string", description: "Link to PR or review document"}
        },
        required: ["context_id", "title", "summary", "status"]
      }
    }
  end

  defp prioritize_requirement do
    %{
      name: "prioritize_requirement",
      description: "Set or update the priority of a project requirement.",
      inputSchema: %{
        type: "object",
        properties: %{
          requirement_id: %{type: "string", description: "The UUID of the requirement memory"},
          priority: %{
            type: "string",
            enum: ["High", "Medium", "Low"]
          }
        },
        required: ["requirement_id", "priority"]
      }
    }
  end

  defp list_by_tag do
    %{
      name: "list_by_tag",
      description: "List memories filtered by a specific tag across the context.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          tag: %{type: "string", description: "The tag to filter by"}
        },
        required: ["context_id", "tag"]
      }
    }
  end

  defp export_context do
    %{
      name: "export_context",
      description:
        "Export the entire context and its memories as a structured document (Markdown/JSON).",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          format: %{
            type: "string",
            enum: ["markdown", "json"],
            description: "Export format"
          }
        },
        required: ["context_id", "format"]
      }
    }
  end

  defp record_analysis_result do
    %{
      name: "record_analysis_result",
      description:
        "Record the output of an automated analysis tool (linter, security scan, etc.).",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          scanner_name: %{
            type: "string",
            description: "Name of the scanner (e.g., Mix Audit, Sobelow)"
          },
          target: %{type: "string", description: "What was scanned (file, module, dependency)"},
          findings: %{type: "string", description: "Summary of results/violations"},
          severity: %{
            type: "string",
            enum: ["critical", "high", "moderate", "low", "info"]
          }
        },
        required: ["context_id", "scanner_name", "findings", "severity"]
      }
    }
  end

  defp link_memories do
    %{
      name: "link_memories",
      description:
        "Link a child memory to a parent memory to create a hierarchy (e.g., linking a Decision to a Requirement).",
      inputSchema: %{
        type: "object",
        properties: %{
          parent_id: %{type: "string", description: "The UUID of the parent memory"},
          child_id: %{type: "string", description: "The UUID of the child memory"}
        },
        required: ["parent_id", "child_id"]
      }
    }
  end

  defp get_memory_tree do
    %{
      name: "get_memory_tree",
      description:
        "Retrieve a memory and all its children recursively to see the context hierarchy.",
      inputSchema: %{
        type: "object",
        properties: %{
          root_id: %{type: "string", description: "The UUID of the root memory to start from"}
        },
        required: ["root_id"]
      }
    }
  end

  defp get_context_health do
    %{
      name: "get_context_health",
      description: "Get the health score and breakdown for a context (Patent #1: Health Engine)",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp run_context_scan do
    %{
      name: "run_context_scan",
      description: "Automatically extract architectural facts from source code (Patent #2: ACE)",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          path: %{
            type: "string",
            description: "Directory path to scan (defaults to project root)"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp list_conflicts do
    %{
      name: "list_conflicts",
      description: "Detect contradictory or overlapping information in the context (Patent #3)",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp resolve_conflict do
    %{
      name: "resolve_conflict",
      description:
        "Resolve a detected knowledge collision by keeping, discarding, or merging memories. Supports manual ID selection or predefined strategies.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          strategy: %{
            type: "string",
            enum: ["auto", "keep_latest", "keep_original"],
            description: "Resolution strategy to apply (Tier 1/2)"
          },
          keep_ids: %{
            type: "array",
            items: %{type: "string"},
            description: "List of Memory IDs to keep as valid (Manual mode)"
          },
          discard_ids: %{
            type: "array",
            items: %{type: "string"},
            description: "List of Memory IDs to archive/delete (Manual mode)"
          },
          reason: %{
            type: "string",
            description: "Optional rationale for the resolution"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp perform_backup do
    %{
      name: "perform_backup",
      description: "Trigger a full system backup of all contexts to the local backup directory.",
      inputSchema: %{
        type: "object",
        properties: %{}
      }
    }
  end
  defp register_agent do
    %{
      name: "register_agent",
      description: "Register an autonomous agent with the Diwa Registry. Returns an Agent ID.",
      inputSchema: %{
        type: "object",
        properties: %{
          name: %{type: "string", description: "Name of the agent (e.g. 'Senior Coder')"},
          role: %{type: "string", description: "Role/Responsibility (coding, qa, architect, general)"},
          capabilities: %{
            type: "array", 
            items: %{type: "string"},
            description: "List of capabilities (e.g. ['elixir', 'testing', 'security'])"
          }
        },
        required: ["name", "role", "capabilities"]
      }
    }
  end

  defp poll_delegated_tasks do
    %{
      name: "poll_delegated_tasks",
      description: "Poll for pending tasks delegated to this agent. Returns a list of tasks.",
      inputSchema: %{
        type: "object",
        properties: %{
          agent_id: %{type: "string", description: "The ID of the agent polling for work"}
        },
        required: ["agent_id"]
      }
    }
  end

  defp delegate_task do
    %{
      name: "delegate_task",
      description: "Delegate a task to another agent. Returns a delegation reference ID.",
      inputSchema: %{
        type: "object",
        properties: %{
          from_agent_id: %{type: "string", description: "ID of the agent sending the task"},
          to_agent_id: %{type: "string", description: "ID of the target agent (optional if role specified)"},
          context_id: %{type: "string", description: "The context this task belongs to"},
          task_definition: %{type: "string", description: "Description of the task to perform"},
          constraints: %{
            type: "object",
             description: "Key-value constraints (e.g. timeout, scope)"
          }
        },
        required: ["from_agent_id", "context_id", "task_definition"]
      }
    }
  end

  defp respond_to_delegation do
    %{
      name: "respond_to_delegation",
      description: "Accept or reject a delegated task.",
      inputSchema: %{
        type: "object",
        properties: %{
          delegation_id: %{type: "string", description: "The ID of the delegation"},
          status: %{type: "string", enum: ["accepted", "rejected"], description: "Response status"},
          reason: %{type: "string", description: "Optional reason for rejection"}
        },
        required: ["delegation_id", "status"]
      }
    }
  end

  defp complete_delegation do
    %{
      name: "complete_delegation",
      description: "Mark a delegated task as complete and provide results.",
      inputSchema: %{
        type: "object",
        properties: %{
          delegation_id: %{type: "string", description: "The ID of the completed delegation"},
          result_summary: %{type: "string", description: "Summary of the work done or findings"},
          artifacts: %{
            type: "array",
            items: %{type: "string"},
            description: "List of artifacts produced (file paths, memory IDs)"
          }
        },
        required: ["delegation_id", "result_summary"]
      }
    }
  end
  defp get_memory_history do
    %{
      name: "get_memory_history",
      description: "View the version history of a specific memory",
      inputSchema: %{
        type: "object",
        properties: %{
          memory_id: %{type: "string", description: "UUID of the memory"}
        },
        required: ["memory_id"]
      }
    }
  end

  defp rollback_memory do
    %{
      name: "rollback_memory",
      description: "Revert a memory to a specific version from its history",
      inputSchema: %{
        type: "object",
        properties: %{
          memory_id: %{type: "string", description: "UUID of the memory to rollback"},
          version_id: %{type: "string", description: "UUID of the version to revert to"},
          reason: %{type: "string", description: "Reason for the rollback"}
        },
        required: ["memory_id", "version_id"]
      }
    }
  end

  defp compare_memory_versions do
    %{
      name: "compare_memory_versions",
      description: "Compare two versions of a memory to see differences",
      inputSchema: %{
        type: "object",
        properties: %{
          version_id_1: %{type: "string"},
          version_id_2: %{type: "string"}
        },
        required: ["version_id_1", "version_id_2"]
      }
    }
  end

  defp get_recent_changes do
    %{
      name: "get_recent_changes",
      description: "List recent changes (versions) across a context",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "UUID of the context"},
          limit: %{type: "integer", default: 20}
        },
        required: ["context_id"]
      }
    }
  end
  defp get_agent_health do
    %{
      name: "get_agent_health",
      description: "Get aggregate metrics and status for a SINAG agent",
      inputSchema: %{
        type: "object",
        properties: %{
          agent_id: %{type: "string", description: "UUID or name of the agent"},
          context_id: %{type: "string", description: "The context the agent is working in"}
        },
        required: ["agent_id", "context_id"]
      }
    }
  end

  defp restore_agent do
    %{
      name: "restore_agent",
      description: "Re-hydrate agent state from the last valid checkpoint",
      inputSchema: %{
        type: "object",
        properties: %{
          agent_id: %{type: "string"},
          context_id: %{type: "string"}
        },
        required: ["agent_id", "context_id"]
      }
    }
  end

  defp log_failure do
    %{
      name: "log_failure",
      description: "Record a structured crash dump or failure event for an agent",
      inputSchema: %{
        type: "object",
        properties: %{
          agent_id: %{type: "string"},
          context_id: %{type: "string"},
          error_category: %{
            type: "string",
            description: "e.g. timeout, crash, hallucination, tool_error"
          },
          severity: %{type: "string", enum: ["low", "moderate", "high", "critical"]},
          stack_trace: %{type: "string"},
          metadata: %{type: "object"}
        },
        required: ["agent_id", "context_id", "error_category", "severity"]
      }
    }
  end

  defp purge_old_checkpoints do
    %{
      name: "purge_old_checkpoints",
      description: "Cleanup tool to remove old checkpoints according to retention policy",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string"},
          retention_days: %{type: "integer", default: 7}
        },
        required: ["context_id"]
      }
    }
  end

  defp arbitrate_conflict do
    %{
      name: "arbitrate_conflict",
      description: "Initiate distributed conflict arbitration using Raft consensus. Coordinates resolution across multiple nodes with Byzantine fault tolerance.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "UUID of the context containing the conflict"
          },
          conflict_id: %{
            type: "string",
            description: "UUID of the conflict to arbitrate"
          },
          participants: %{
            type: "array",
            items: %{type: "string"},
            description: "List of node IDs to participate in arbitration (optional, defaults to all cluster nodes)"
          },
          timeout_ms: %{
            type: "integer",
            description: "Timeout in milliseconds for arbitration (default: 5000)",
            default: 5000
          }
        },
        required: ["context_id", "conflict_id"]
      }
    }
  end

  defp get_cluster_status do
    %{
      name: "get_cluster_status",
      description: "Get the current status of the distributed consensus cluster, including membership, health, and leader information.",
      inputSchema: %{
        type: "object",
        properties: %{
          include_metrics: %{
            type: "boolean",
            description: "Include detailed performance metrics (default: false)",
            default: false
          }
        }
      }
    }
  end

  defp get_byzantine_nodes do
    %{
      name: "get_byzantine_nodes",
      description: "List nodes that have been identified as Byzantine (faulty/malicious) and their suspicion levels. Includes quarantined nodes and those under investigation.",
      inputSchema: %{
        type: "object",
        properties: %{
          min_suspicion_level: %{
            type: "string",
            enum: ["none", "low", "medium", "high", "confirmed"],
            description: "Minimum suspicion level to include (default: medium)",
            default: "medium"
          },
          include_history: %{
            type: "boolean",
            description: "Include behavior history for each node (default: false)",
            default: false
          }
        }
      }
    }
  end

  # --- Shortcut Interpreter Tools ---

  defp execute_shortcut do
    %{
      name: "execute_shortcut",
      description: "Execute a shortcut command string. Resolves aliases and invokes the target MCP tool.",
      inputSchema: %{
        type: "object",
        properties: %{
          command: %{
            type: "string", 
            description: "The full shortcut string (e.g. '/bug \"Failed validation\"')"
          },
          context_id: %{
            type: "string",
            description: "The context ID to execute the tool in"
          }
        },
        required: ["command", "context_id"]
      }
    }
  end

  defp list_shortcuts do
    %{
      name: "list_shortcuts",
      description: "List all available registered shortcuts and their definitions.",
      inputSchema: %{
        type: "object",
        properties: %{},
        required: []
      }
    }
  end

  defp register_shortcut_alias do
    %{
      name: "register_shortcut_alias",
      description: "Register a new custom shortcut alias.",
      inputSchema: %{
        type: "object",
        properties: %{
          alias_name: %{
            type: "string",
            description: "The name of the new shortcut (without slash)"
          },
          target_tool: %{
            type: "string", 
            description: "The actual MCP tool to call (e.g. 'log_progress')"
          },
          args_schema: %{
            type: "array",
            items: %{type: "string"},
            description: "List of argument keys to map positional args to (e.g. ['message', 'title'])"
          }
        },
        required: ["alias_name", "target_tool"]
      }
    }
  end

  defp classify_memory do
    %{
      name: "classify_memory",
      description: "Analyze and classify a piece of content into a memory class (e.g., requirement, decision).",
      inputSchema: %{
        type: "object",
        properties: %{
          content: %{type: "string", description: "The content to classify"},
          filename: %{type: "string", description: "Optional filename to aid classification"}
        },
        required: ["content"]
      }
    }
  end

  defp ingest_context do
    %{
      name: "ingest_context",
      description: "Scan local project directories (.agent, .cursor) and ingest classified files as memories.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "Target context ID"},
          directories: %{
            type: "array",
            items: %{type: "string"},
            description: "List of directory paths to scan (default: .agent, .cursor)"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp start_session do
    %{
      name: "start_session",
      description: "Start a new development session for activity tracking.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "Target context ID"},
          actor: %{type: "string", description: "The agent or human starting the session"},
          metadata: %{type: "object", description: "Additional session metadata"}
        },
        required: ["context_id", "actor"]
      }
    }
  end

  defp log_session_activity do
    %{
      name: "log_session_activity",
      description: "Log an activity or update to the current session.",
      inputSchema: %{
        type: "object",
        properties: %{
          session_id: %{type: "string", description: "ID of the active session"},
          message: %{type: "string", description: "Activity message"},
          metadata: %{type: "object", description: "Additional details (e.g., active_files)"}
        },
        required: ["session_id", "message"]
      }
    }
  end

  defp end_session do
    %{
      name: "end_session",
      description: "End the development session and generate a handoff note.",
      inputSchema: %{
        type: "object",
        properties: %{
          session_id: %{type: "string", description: "ID of the session to end"},
          summary: %{type: "string", description: "Final summary of accomplishments"},
          next_steps: %{
            type: "array",
            items: %{type: "string"},
            description: "List of tactical next steps for the next agent"
          }
        },
        required: ["session_id", "summary"]
      }
    }
  end

  defp hydrate_context do
    %{
      name: "hydrate_context",
      description: "Retrieve a smart context briefing for an agent based on depth and focus.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "Target context ID"},
          depth: %{
            type: "string",
            enum: ["minimal", "standard", "comprehensive"],
            description: "Context retrieval depth"
          },
          focus: %{
            type: "array",
            items: %{type: "string"},
            description: "List of keywords or tags to prioritize"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp validate_action do
    %{
      name: "validate_action",
      description: "Check a proposed action or content against project rules and standards.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "Target context ID"},
          content: %{type: "string", description: "The action or content to validate"},
          mode: %{
            type: "string",
            enum: ["strict", "warn", "audit"],
            description: "Enforcement mode"
          }
        },
        required: ["context_id", "content"]
      }
    }
  end

  defp prune_expired_memories do
    %{
      name: "prune_expired_memories",
      description: "Clean up all expired memories across contexts.",
      inputSchema: %{
        type: "object",
        properties: %{}
      }
    }
  end
end
