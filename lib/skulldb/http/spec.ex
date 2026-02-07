defmodule Skulldb.HTTP.Spec do
  @moduledoc """
  OpenAPI specification for SkullDB HTTP API.
  Defines all endpoints, request/response schemas, and documentation.
  """

  alias OpenApiSpex.{
    Components,
    Contact,
    Info,
    License,
    OpenApi,
    Operation,
    Parameter,
    PathItem,
    RequestBody,
    Response,
    Schema,
    SecurityScheme
  }

  def spec do
    %OpenApi{
      servers: [
        %OpenApiSpex.Server{url: "http://localhost:4000", description: "Development server"},
        %OpenApiSpex.Server{url: "http://localhost:8080", description: "Docker server"}
      ],
      info: %Info{
        title: "SkullDB API",
        description: "Graph database API - Store, query, and manage graph data with SkullDB",
        version: Application.spec(:skulldb, :vsn) |> to_string(),
        contact: %Contact{
          name: "SkullDB Community",
          url: "https://github.com/your-org/skulldb"
        },
        license: %License{
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      paths: paths(),
      components: components(),
      security: [%{"bearerAuth" => []}]
    }
  end

  defp paths do
    %{
      "/health" => %PathItem{
        get: health_operation()
      },
      "/auth/register" => %PathItem{
        post: register_operation()
      },
      "/auth/login" => %PathItem{
        post: login_operation()
      },
      "/auth/verify" => %PathItem{
        post: verify_operation()
      },
      "/nodes" => %PathItem{
        get: list_nodes_operation(),
        post: create_node_operation()
      },
      "/nodes/{id}" => %PathItem{
        get: get_node_operation(),
        put: update_node_operation(),
        delete: delete_node_operation()
      },
      "/edges" => %PathItem{
        get: list_edges_operation(),
        post: create_edge_operation()
      },
      "/edges/{id}" => %PathItem{
        get: get_edge_operation(),
        delete: delete_edge_operation()
      },
      "/query" => %PathItem{
        post: query_operation()
      }
    }
  end

  # ========================================
  # Health Check
  # ========================================

  defp health_operation do
    %Operation{
      summary: "Health check",
      description: "Check if the server is running and get version information",
      tags: ["Health"],
      security: [],
      responses: %{
        "200" => %Response{
          description: "Server is healthy",
          content: %{
            "application/json" => %OpenApiSpex.MediaType{
              schema: health_response_schema()
            }
          }
        }
      }
    }
  end

  defp health_response_schema do
    %Schema{
      title: "HealthResponse",
      type: :object,
      properties: %{
        status: %Schema{type: :string, example: "ok"},
        version: %Schema{type: :string, example: "0.1.0"},
        docs: %Schema{type: :string}
      },
      required: [:status, :version]
    }
  end

  # ========================================
  # Authentication Operations
  # ========================================

  defp register_operation do
    %Operation{
      summary: "Register a new user",
      description: "Create a new user account with email and password",
      tags: ["Authentication"],
      security: [],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "RegisterRequest",
              type: :object,
              properties: %{
                email: %Schema{type: :string, format: :email, example: "user@example.com"},
                password: %Schema{type: :string, format: :password, example: "securepassword"},
                metadata: %Schema{
                  type: :object,
                  example: %{"name" => "John Doe"},
                  description: "Optional user metadata"
                }
              },
              required: [:email, :password]
            }
          }
        }
      },
      responses: %{
        "201" => success_response("User registered successfully", register_response_schema()),
        "400" => error_response("Bad request")
      }
    }
  end

  defp register_response_schema do
    %Schema{
      title: "RegisterResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        user: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            email: %Schema{type: :string, format: :email}
          }
        }
      },
      required: [:success, :user]
    }
  end

  defp login_operation do
    %Operation{
      summary: "Login user",
      description: "Authenticate with email and password to get a JWT token",
      tags: ["Authentication"],
      security: [],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "LoginRequest",
              type: :object,
              properties: %{
                email: %Schema{type: :string, format: :email},
                password: %Schema{type: :string, format: :password}
              },
              required: [:email, :password]
            }
          }
        }
      },
      responses: %{
        "200" => success_response("User authenticated successfully", login_response_schema()),
        "401" => error_response("Invalid credentials"),
        "400" => error_response("Bad request")
      }
    }
  end

  defp login_response_schema do
    %Schema{
      title: "LoginResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        token: %Schema{type: :string, description: "JWT authentication token"}
      },
      required: [:success, :token]
    }
  end

  defp verify_operation do
    %Operation{
      summary: "Verify token",
      description: "Verify JWT token and get user information",
      tags: ["Authentication"],
      security: [],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "VerifyRequest",
              type: :object,
              properties: %{
                token: %Schema{type: :string}
              },
              required: [:token]
            }
          }
        }
      },
      responses: %{
        "200" => success_response("Token verified successfully", verify_response_schema()),
        "401" => error_response("Invalid token")
      }
    }
  end

  defp verify_response_schema do
    %Schema{
      title: "VerifyResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        payload: %Schema{type: :object}
      },
      required: [:success, :payload]
    }
  end

  # ========================================
  # Node Operations
  # ========================================

  defp list_nodes_operation do
    %Operation{
      summary: "List all nodes",
      description: "Get all graph nodes for the authenticated user",
      tags: ["Nodes"],
      security: [%{"bearerAuth" => []}],
      responses: %{
        "200" => success_response("Nodes retrieved successfully", nodes_list_response_schema()),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp get_node_operation do
    %Operation{
      summary: "Get node by ID",
      description: "Retrieve a specific node with its properties and labels",
      tags: ["Nodes"],
      security: [%{"bearerAuth" => []}],
      parameters: [
        %Parameter{
          name: :id,
          in: :path,
          required: true,
          schema: %Schema{type: :string, format: :uuid}
        }
      ],
      responses: %{
        "200" => success_response("Node retrieved successfully", node_response_schema()),
        "401" => error_response("Unauthorized"),
        "404" => error_response("Node not found")
      }
    }
  end

  defp create_node_operation do
    %Operation{
      summary: "Create a new node",
      description: "Create a new graph node with labels and properties",
      tags: ["Nodes"],
      security: [%{"bearerAuth" => []}],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "CreateNodeRequest",
              type: :object,
              properties: %{
                labels: %Schema{
                  type: :array,
                  items: %Schema{type: :string},
                  example: ["Person", "User"]
                },
                properties: %Schema{
                  type: :object,
                  example: %{"name" => "John", "age" => 30}
                }
              },
              required: [:labels]
            }
          }
        }
      },
      responses: %{
        "201" => success_response("Node created successfully", node_response_schema()),
        "400" => error_response("Bad request"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp update_node_operation do
    %Operation{
      summary: "Update node",
      description: "Update properties of an existing node",
      tags: ["Nodes"],
      security: [%{"bearerAuth" => []}],
      parameters: [
        %Parameter{
          name: :id,
          in: :path,
          required: true,
          schema: %Schema{type: :string, format: :uuid}
        }
      ],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "UpdateNodeRequest",
              type: :object,
              properties: %{
                changes: %Schema{
                  type: :object,
                  example: %{"name" => "Jane", "age" => 31}
                }
              },
              required: [:changes]
            }
          }
        }
      },
      responses: %{
        "200" => success_response("Node updated successfully"),
        "400" => error_response("Bad request"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp delete_node_operation do
    %Operation{
      summary: "Delete node",
      description: "Delete a node and all its associated edges",
      tags: ["Nodes"],
      security: [%{"bearerAuth" => []}],
      parameters: [
        %Parameter{
          name: :id,
          in: :path,
          required: true,
          schema: %Schema{type: :string, format: :uuid}
        }
      ],
      responses: %{
        "200" => success_response("Node deleted successfully"),
        "400" => error_response("Bad request"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp node_response_schema do
    %Schema{
      title: "NodeResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        node: node_schema()
      },
      required: [:success, :node]
    }
  end

  defp nodes_list_response_schema do
    %Schema{
      title: "NodesListResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        nodes: %Schema{
          type: :array,
          items: node_schema()
        }
      },
      required: [:success, :nodes]
    }
  end

  defp node_schema do
    %Schema{
      title: "Node",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        labels: %Schema{
          type: :array,
          items: %Schema{type: :string}
        },
        properties: %Schema{type: :object}
      },
      required: [:id, :labels, :properties]
    }
  end

  # ========================================
  # Edge Operations
  # ========================================

  defp list_edges_operation do
    %Operation{
      summary: "List all edges",
      description: "Get all graph edges",
      tags: ["Edges"],
      security: [%{"bearerAuth" => []}],
      responses: %{
        "200" => success_response("Edges retrieved successfully", edges_list_response_schema()),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp get_edge_operation do
    %Operation{
      summary: "Get edge by ID",
      description: "Retrieve a specific edge with its properties",
      tags: ["Edges"],
      security: [%{"bearerAuth" => []}],
      parameters: [
        %Parameter{
          name: :id,
          in: :path,
          required: true,
          schema: %Schema{type: :string, format: :uuid}
        }
      ],
      responses: %{
        "200" => success_response("Edge retrieved successfully", edge_response_schema()),
        "401" => error_response("Unauthorized"),
        "404" => error_response("Edge not found")
      }
    }
  end

  defp create_edge_operation do
    %Operation{
      summary: "Create a new edge",
      description: "Create a relationship between two nodes",
      tags: ["Edges"],
      security: [%{"bearerAuth" => []}],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "CreateEdgeRequest",
              type: :object,
              properties: %{
                type: %Schema{type: :string, example: "FOLLOWS"},
                from: %Schema{type: :string, format: :uuid, description: "Source node ID"},
                to: %Schema{type: :string, format: :uuid, description: "Target node ID"},
                properties: %Schema{
                  type: :object,
                  example: %{"since" => "2024-01-01"}
                }
              },
              required: [:type, :from, :to]
            }
          }
        }
      },
      responses: %{
        "201" => success_response("Edge created successfully", edge_response_schema()),
        "400" => error_response("Bad request"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp delete_edge_operation do
    %Operation{
      summary: "Delete edge",
      description: "Delete a relationship between nodes",
      tags: ["Edges"],
      security: [%{"bearerAuth" => []}],
      parameters: [
        %Parameter{
          name: :id,
          in: :path,
          required: true,
          schema: %Schema{type: :string, format: :uuid}
        }
      ],
      responses: %{
        "200" => success_response("Edge deleted successfully"),
        "400" => error_response("Bad request"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp edge_response_schema do
    %Schema{
      title: "EdgeResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        edge: edge_schema()
      },
      required: [:success, :edge]
    }
  end

  defp edges_list_response_schema do
    %Schema{
      title: "EdgesListResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        edges: %Schema{
          type: :array,
          items: edge_schema()
        }
      },
      required: [:success, :edges]
    }
  end

  defp edge_schema do
    %Schema{
      title: "Edge",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        type: %Schema{type: :string},
        from: %Schema{type: :string, format: :uuid},
        to: %Schema{type: :string, format: :uuid},
        properties: %Schema{type: :object}
      },
      required: [:id, :type, :from, :to, :properties]
    }
  end

  defp query_operation do
    %Operation{
      summary: "Execute query",
      description: "Execute a SkullQL query against the database",
      tags: ["Query"],
      security: [%{"bearerAuth" => []}],
      requestBody: %RequestBody{
        required: true,
        content: %{
          "application/json" => %OpenApiSpex.MediaType{
            schema: %Schema{
              title: "QueryRequest",
              type: :object,
              properties: %{
                query: %Schema{
                  type: :string,
                  description: "SkullQL query string",
                  example: "MATCH (n:Person) RETURN n"
                }
              },
              required: [:query]
            }
          }
        }
      },
      responses: %{
        "200" => success_response("Query executed successfully", query_response_schema()),
        "400" => error_response("Invalid query"),
        "401" => error_response("Unauthorized")
      }
    }
  end

  defp query_response_schema do
    %Schema{
      title: "QueryResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        results: %Schema{
          type: :array,
          items: %Schema{type: :object}
        }
      },
      required: [:success, :results]
    }
  end

  # ========================================
  # Common Helper Functions
  # ========================================

  defp success_response(description, schema \\ nil) do
    %Response{
      description: description,
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: schema || success_response_schema()
        }
      }
    }
  end

  defp success_response_schema do
    %Schema{
      title: "SuccessResponse",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        message: %Schema{type: :string}
      },
      required: [:success]
    }
  end

  defp error_response(description) do
    %Response{
      description: description,
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %Schema{
            title: "ErrorResponse",
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: false},
              error: %Schema{type: :string}
            },
            required: [:success, :error]
          }
        }
      }
    }
  end

  defp components do
    %Components{
      securitySchemes: %{
        "bearerAuth" => %SecurityScheme{
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
          description: "JWT authentication token from /auth/login"
        }
      }
    }
  end
end
