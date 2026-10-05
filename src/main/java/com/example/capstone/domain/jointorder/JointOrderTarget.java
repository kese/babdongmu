package com.example.capstone.domain.jointorder;

import com.example.capstone.domain.post.Post;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "joint_order_targets")
public class JointOrderTarget {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "target_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "request_id", nullable = false)
    private JointOrderRequest jointOrderRequest;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_post_id", nullable = false)
    private Post targetPost;
}
