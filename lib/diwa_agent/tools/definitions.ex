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
      # REMOVED: get_context_health() - Patent D1 (Enterprise only)
      # REMOVED: run_context_scan() - Patent D2 (Enterprise only)
      # REMOVED: list_conflicts() - Patent D3 (Enterprise only)
      # REMOVED: resolve_conflict() - Patent D3 (Enterprise only)
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
      complete_handoff(),
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

      # Agent Coordination (Phase 1.4) - Community Edition has basic delegation
      # REMOVED: register_agent() - SINAG runtime (Enterprise only)
      # REMOVED: match_experts() - SINAG runtime (Enterprise only)
      # REMOVED: poll_delegated_tasks() - SINAG runtime (Enterprise only)
      # REMOVED: delegate_task() - SINAG runtime (Enterprise only)
      # REMOVED: respond_to_delegation() - SINAG runtime (Enterprise only)
      # REMOVED: complete_delegation() - SINAG runtime (Enterprise only)

      # SINAG Lifecycle Tools (Phase 3.2) - Enterprise only
      # REMOVED: get_agent_health() - SINAG runtime (Enterprise only)
      # REMOVED: restore_agent() - SINAG runtime (Enterprise only)
      # REMOVED: log_failure() - SINAG runtime (Enterprise only)
      # REMOVED: purge_old_checkpoints() - SINAG runtime (Enterprise only)

      # Ledger and Rollback Tools (Phase 3.1)
      get_memory_history(),
      rollback_memory(),
      compare_memory_versions(),
      get_recent_changes(),

      # Distributed Consensus Tools (Phase 3) - Enterprise only
      # REMOVED: arbitrate_conflict() - Patent D3 (Enterprise only)
      # REMOVED: get_cluster_status() - Cluster consensus (Enterprise only)
      # REMOVED: get_byzantine_nodes() - Cluster consensus (Enterprise only)

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
      prune_expired_memories(),

      # UGAT Tools (Context Intelligence Backbone)
      detect_context(),
      bind_context(),
      unbind_context(),
      list_bindings(),
      link_contexts(),
      unlink_contexts(),
      get_related_contexts(),
      get_context_graph(),
      get_dependency_chain(),
      get_shortcuts(),
      navigate_contexts(),
      analyze_impact(),
      find_shortest_path(),

      # Code Visibility Tools (TANAW Integration)
      list_directory(),
      read_file(),
      search_code(),

      # TALA Tools
      commit_buffer(),
      list_pending(),
      get_client_instructions(),
      determine_workflow(),
      queue_handoff_item(),

      # UGAT Onboarding
      confirm_binding()
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

  defp start_session do
    %{
      name: "start_session",
      description:
        "Detect project context from current directory and retrieve session resume with handoff, pending tasks, and shortcuts",
      inputSchema: %{
        type: "object",
        properties: %{
          path: %{
            type: "string",
            description:
              "Directory path to detect context from. Client should pass actual filesystem path."
          },
          git_remote: %{
            type: "string",
            description:
              "Git remote URL. If omitted, auto-detected via 'git remote get-url origin'."
          },
          depth: %{
            type: "string",
            enum: ["minimal", "standard", "comprehensive"],
            description: "How much context to retrieve"
          },
          actor: %{
            type: "string",
            description: "The agent or human starting the session"
          },
          context_id: %{
            type: "string",
            description: "Direct Context ID (optional override)"
          },
          client_type: %{
            type: "string",
            description:
              "Type of client (e.g., 'antigravity') for self-configuration instructions"
          }
        },
        additionalProperties: false
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
          },
          query: %{
            type: "string",
            description: "Optional fuzzy search query to filter contexts by name"
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
          },
          buffer: %{
            type: "boolean",
            description:
              "If true, buffer the operation for TALA instead of executing immediately",
            default: false
          },
          session_id: %{
            type: "string",
            description: "The UUID of the active session (required if buffer=true)"
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
          },
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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
          },
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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
          },
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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
          },
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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

  defp complete_handoff do
    %{
      name: "complete_handoff",
      description: "Mark a handoff as completed and acknowledge next steps.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          handoff_id: %{type: "string", description: "The ID of the handoff memory"},
          status: %{
            type: "string",
            enum: ["completed", "rejected"],
            description: "Outcome of the handoff"
          }
        },
        required: ["context_id", "handoff_id"]
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
          tags: %{type: "string", description: "Optional comma-separated tags"},
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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
          alternatives: %{type: "string", description: "What other options were considered"},
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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
          external_ref: %{type: "string", description: "Link to monitoring dashboard or ticket"},
          buffer: %{type: "boolean", description: "If true, buffer for TALA", default: false}
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

  # REMOVED: get_context_health - Patent D1 (Enterprise only)

  # REMOVED: run_context_scan - Patent D2 (Enterprise only)
  # REMOVED: list_conflicts - Patent D3 (Enterprise only)
  # REMOVED: resolve_conflict - Patent D3 (Enterprise only)

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

  # REMOVED: SINAG Runtime Tools (Enterprise only)
  # - register_agent
  # - match_experts
  # - poll_delegated_tasks
  # - delegate_task
  # - respond_to_delegation
  # - complete_delegation

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

  # REMOVED: SINAG Lifecycle Tools (Enterprise only)
  # - get_agent_health
  # - restore_agent
  # - log_failure
  # - purge_old_checkpoints

  # REMOVED: Conflict & Consensus Tools (Enterprise only)
  # - arbitrate_conflict
  # - get_cluster_status
  # - get_byzantine_nodes

  # --- Shortcut Interpreter Tools ---

  defp execute_shortcut do
    %{
      name: "execute_shortcut",
      description:
        "Execute a shortcut command string. Resolves aliases and invokes the target MCP tool.",
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
            description:
              "List of argument keys to map positional args to (e.g. ['message', 'title'])"
          }
        },
        required: ["alias_name", "target_tool"]
      }
    }
  end

  defp classify_memory do
    %{
      name: "classify_memory",
      description:
        "Analyze and classify a piece of content into a memory class (e.g., requirement, decision).",
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
      description:
        "Scan local project directories (.agent, .cursor) and ingest classified files as memories.",
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

  # --- UGAT Tools ---

  defp detect_context do
    %{
      name: "detect_context",
      description: "Auto-detect which context to use based on environment (git, path, etc).",
      inputSchema: %{
        type: "object",
        properties: %{
          type: %{
            type: "string",
            description: "The type of binding to check (git_remote, path, env_var)"
          },
          value: %{
            type: "string",
            description: "The value to check against (e.g. current git remote url)"
          }
        },
        required: ["type", "value"]
      }
    }
  end

  defp bind_context do
    %{
      name: "bind_context",
      description:
        "Bind a context to a specific environment trigger (e.g. this git repo maps to this context).",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the context"},
          type: %{type: "string", description: "Binding type (git_remote, path, env_var)"},
          value: %{type: "string", description: "Trigger value (e.g. git url)"},
          metadata: %{type: "string", description: "Optional JSON metadata"}
        },
        required: ["context_id", "type", "value"]
      }
    }
  end

  defp unbind_context do
    %{
      name: "unbind_context",
      description: "Remove a context binding.",
      inputSchema: %{
        type: "object",
        properties: %{
          binding_id: %{type: "string", description: "The UUID of the binding to remove"}
        },
        required: ["binding_id"]
      }
    }
  end

  defp list_bindings do
    %{
      name: "list_bindings",
      description: "List all auto-detection bindings for a context.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp link_contexts do
    %{
      name: "link_contexts",
      description: "Create a semantic link/relationship between two contexts.",
      inputSchema: %{
        type: "object",
        properties: %{
          source_context_id: %{type: "string", description: "The source context UUID"},
          target_context_id: %{type: "string", description: "The target context UUID"},
          relationship_type: %{
            type: "string",
            description: "Type of relationship (depends_on, relates_to, child_of, blocks)"
          },
          metadata: %{type: "string", description: "Optional JSON metadata"}
        },
        required: ["source_context_id", "target_context_id", "relationship_type"]
      }
    }
  end

  defp unlink_contexts do
    %{
      name: "unlink_contexts",
      description: "Remove a link between contexts.",
      inputSchema: %{
        type: "object",
        properties: %{
          relationship_id: %{
            type: "string",
            description: "The UUID of the relationship to remove"
          }
        },
        required: ["relationship_id"]
      }
    }
  end

  defp get_related_contexts do
    %{
      name: "get_related_contexts",
      description: "List related linked contexts.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the context"},
          direction: %{
            type: "string",
            enum: ["outgoing", "incoming", "both"],
            description: "Direction of relationships"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp get_context_graph do
    %{
      name: "get_context_graph",
      description: "Traverse the context graph and return a visualization (Mermaid/JSON).",
      inputSchema: %{
        type: "object",
        properties: %{
          root_id: %{
            type: "string",
            description: "The UUID of the root context to start traversal"
          },
          depth: %{type: "integer", description: "Maximum depth of traversal (default: 3)"},
          format: %{
            type: "string",
            enum: ["mermaid", "json", "list"],
            description: "Output format (default: mermaid)"
          }
        },
        required: ["root_id"]
      }
    }
  end

  defp get_dependency_chain do
    %{
      name: "get_dependency_chain",
      description:
        "Retrieve a topologically sorted list of dependencies for a context (Build Order).",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp get_shortcuts do
    %{
      name: "get_shortcuts",
      description: "List available registered shortcuts and their definitions.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "Optional: Context ID to include in shortcut usage examples"
          }
        },
        required: []
      }
    }
  end

  defp navigate_contexts do
    %{
      name: "navigate_contexts",
      description:
        "Interactive navigation of the context graph (ls-style). Supports listing, tree view, and detailed inspection.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{
            type: "string",
            description: "The ID of the context you are currently 'inside' (PWD)"
          },
          target_path: %{
            type: "string",
            description: "Path to navigate to (e.g., '.', '..', 'child_name', or absolute ID)"
          },
          mode: %{
            type: "string",
            enum: ["list", "tree", "detail"],
            description: "View mode: 'list' (ls), 'tree' (tree), 'detail' (stat)"
          }
        },
        required: ["context_id"]
      }
    }
  end

  defp analyze_impact do
    %{
      name: "analyze_impact",
      description:
        "Identifies all downstream contexts impacted by a change to the target context.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"}
        },
        required: ["context_id"]
      }
    }
  end

  defp find_shortest_path do
    %{
      name: "find_shortest_path",
      description: "Finds the shortest relationship chain between two contexts.",
      inputSchema: %{
        type: "object",
        properties: %{
          source_context_id: %{type: "string", description: "Start Context ID"},
          target_context_id: %{type: "string", description: "End Context ID"}
        },
        required: ["source_context_id", "target_context_id"]
      }
    }
  end

  defp commit_buffer do
    %{
      name: "commit_buffer",
      description:
        "Flush the TALA buffer and execute all pending operations in a single transaction (Transactional Accumulation & Lazy Apply)",
      inputSchema: %{
        type: "object",
        properties: %{
          session_id: %{type: "string", description: "The UUID of the active session"}
        },
        required: ["session_id"]
      }
    }
  end

  defp list_pending do
    %{
      name: "list_pending",
      description: "List all operations currently buffered in TALA for the session",
      inputSchema: %{
        type: "object",
        properties: %{
          session_id: %{type: "string", description: "The UUID of the active session"}
        },
        required: ["session_id"]
      }
    }
  end

  defp get_client_instructions do
    %{
      name: "get_client_instructions",
      description:
        "Retrieve system prompt snippets for MCP clients to self-configure DIWA conventions (shortcuts, session workflow).",
      inputSchema: %{
        type: "object",
        properties: %{
          client_type: %{
            type: "string",
            description:
              "Type of client requesting instructions (e.g., 'antigravity', 'cursor', 'claude-desktop')"
          },
          sections: %{
            type: "array",
            items: %{
              type: "string",
              enum: ["shortcuts", "session", "workflow"]
            },
            description: "Specific sections of instructions to retrieve"
          },
          version: %{
            type: "string",
            description: "Instruction set version (default: 'v1')"
          }
        },
        required: []
      }
    }
  end

  defp confirm_binding do
    %{
      name: "confirm_binding",
      description:
        "Handles user choice for binding a context to a detected path or git remote. Part of the UGAT onboarding flow.",
      inputSchema: %{
        type: "object",
        properties: %{
          action: %{
            type: "string",
            enum: ["bind", "session_only", "create_new"],
            description: "Onboarding action to take"
          },
          context_id: %{
            type: "string",
            description: "Context UUID for 'bind' action"
          },
          context_name: %{
            type: "string",
            description: "Name for new context if 'create_new' is chosen"
          },
          binding_value: %{
            type: "string",
            description: "The path or git remote URL to bind"
          },
          binding_type: %{
            type: "string",
            enum: ["git_remote", "path"],
            default: "git_remote"
          },
          actor: %{
            type: "string",
            description: "The agent or human performing the action"
          }
        },
        required: ["action", "binding_value"]
      }
    }
  end

  defp list_directory do
    %{
      name: "list_directory",
      description: "List files and directories at a given path within the context's workspace.",
      inputSchema: %{
        type: "object",
        properties: %{
          path: %{
            type: "string",
            description: "Relative path from project root (default: '.')"
          },
          context_id: %{
            type: "string",
            description: "Optional Context ID to determine project root"
          }
        }
      }
    }
  end

  defp read_file do
    %{
      name: "read_file",
      description: "Read the contents of a source file within the workspace.",
      inputSchema: %{
        type: "object",
        properties: %{
          path: %{
            type: "string",
            description: "File path relative to project root"
          },
          start_line: %{
            type: "integer",
            description: "Optional start line (1-indexed)"
          },
          end_line: %{
            type: "integer",
            description: "Optional end line (1-indexed)"
          },
          context_id: %{
            type: "string",
            description: "Optional Context ID to determine project root"
          }
        },
        required: ["path"]
      }
    }
  end

  defp search_code do
    %{
      name: "search_code",
      description: "Search for text/patterns across the codebase using ripgrep.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Search query or regex"
          },
          file_pattern: %{
            type: "string",
            description: "Optional glob pattern (e.g., '*.ex')"
          },
          context_id: %{
            type: "string",
            description: "Optional Context ID to determine project root"
          }
        },
        required: ["query"]
      }
    }
  end

  defp determine_workflow do
    %{
      name: "determine_workflow",
      description: "Auto-detect appropriate workflow based on active spec and task context.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Optional task query or objective to refine workflow detection"
          },
          context_id: %{
            type: "string",
            description: "Optional context ID for context-aware workflow routing"
          }
        }
      }
    }
  end

  defp queue_handoff_item do
    %{
      name: "queue_handoff_item",
      description:
        "Queue a specific note or accomplishment to be included in the next handoff note.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string", description: "The UUID of the project context"},
          message: %{type: "string", description: "The item to queue for the next handoff"},
          category: %{
            type: "string",
            enum: ["accomplishment", "next_step", "blocker", "decision"],
            default: "accomplishment"
          }
        },
        required: ["context_id", "message"]
      }
    }
  end
end
