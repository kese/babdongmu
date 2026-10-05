package com.example.capstone.domain.jointorder;

import com.example.capstone.domain.User;
import com.example.capstone.domain.post.Post;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "joint_order_responses", 
       uniqueConstraints = @UniqueConstraint(columnNames = {"request_id", "post_id"}))
public class JointOrderResponse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "response_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "request_id", nullable = false)
    private JointOrderRequest jointOrderRequest;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "responder_id", nullable = false)
    private User responder;

    @Column(name = "accepted", nullable = false)
    private Boolean accepted;

    @Column(name = "response_time", nullable = false)
    private LocalDateTime responseTime;

    @PrePersist
    protected void onCreate() {
        if (this.responseTime == null) {
            this.responseTime = LocalDateTime.now();
        }
    }

    public boolean isAccepted() {
        return Boolean.TRUE.equals(this.accepted);
    }
}
