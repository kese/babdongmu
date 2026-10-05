package com.example.capstone.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class OpcResponse {
    @JsonProperty("opcode")
    private String opcode;
    
    @JsonProperty("response")
    private String response;
    
    @JsonProperty("code")
    private int code;
    
    @JsonProperty("params")
    private java.util.Map<String, String> params;

    public OpcResponse() {}

    public OpcResponse(String opcode, String response, int code) {
        this.opcode = opcode;
        this.response = response;
        this.code = code;
    }

    public OpcResponse(String opcode, String response, int code, java.util.Map<String, String> params) {
        this.opcode = opcode;
        this.response = response;
        this.code = code;
        this.params = params;
    }

    // Getters and Setters
    public String getOpcode() {
        return opcode;
    }

    public void setOpcode(String opcode) {
        this.opcode = opcode;
    }

    public String getResponse() {
        return response;
    }

    public void setResponse(String response) {
        this.response = response;
    }

    public int getCode() {
        return code;
    }

    public void setCode(int code) {
        this.code = code;
    }

    public java.util.Map<String, String> getParams() {
        return params;
    }

    public void setParams(java.util.Map<String, String> params) {
        this.params = params;
    }
}
