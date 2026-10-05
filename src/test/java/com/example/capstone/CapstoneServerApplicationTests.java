package com.example.capstone;

import com.example.capstone.repository.AuthEventRepository;
import com.example.capstone.repository.ChatMessageRepository;
import com.example.capstone.repository.ChatRoomParticipantRepository;
import com.example.capstone.repository.ChatRoomRepository;
import com.example.capstone.repository.DeliveryDetailRepository;
import com.example.capstone.repository.DeliverySettlementRepository;
import com.example.capstone.repository.FcmTokenRepository;
import com.example.capstone.repository.SharedCartItemRepository;
import com.example.capstone.repository.SharedCartRepository;
import com.example.capstone.repository.SettlementRequestRepository;
import com.example.capstone.repository.PostMeetDetailRepository;
import com.example.capstone.repository.PostParticipantRepository;
import com.example.capstone.repository.PostRepository;
import com.example.capstone.repository.UserRepository;
import com.example.capstone.repository.JointOrderRequestRepository;
import com.example.capstone.repository.NotificationSendHistoryRepository;
import com.example.capstone.repository.PlacesRepository;
import com.example.capstone.service.FcmService;
import com.example.capstone.service.JointOrderService;
import com.example.capstone.service.JointOrderTimeoutService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;
import org.springframework.messaging.simp.SimpMessagingTemplate;

@SpringBootTest
@TestPropertySource(properties = {
    "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration"
    ,"firebase.enabled=false"
})
class CapstoneServerApplicationTests {

    // JPA 비활성화 상태에서 컨텍스트 로딩을 위해 리포지토리를 목 처리
    @MockBean
    private UserRepository userRepository;

    @MockBean
    private AuthEventRepository authEventRepository;

    @MockBean
    private PostRepository postRepository;

    @MockBean
    private PostParticipantRepository postParticipantRepository;

    @MockBean
    private ChatRoomParticipantRepository chatRoomParticipantRepository;

    @MockBean
    private ChatMessageRepository chatMessageRepository;

    @MockBean
    private DeliveryDetailRepository deliveryDetailRepository;

    @MockBean
    private PostMeetDetailRepository postMeetDetailRepository;

    @MockBean
    private ChatRoomRepository chatRoomRepository;

    @MockBean
    private FcmTokenRepository fcmTokenRepository;

    @MockBean
    private SharedCartRepository sharedCartRepository;

    @MockBean
    private SharedCartItemRepository sharedCartItemRepository;

    @MockBean
    private DeliverySettlementRepository deliverySettlementRepository;

    @MockBean
    private FcmService fcmService;

    @MockBean
    private SimpMessagingTemplate simpMessagingTemplate;

    @MockBean
    private SettlementRequestRepository settlementRequestRepository;

    // Joint Order 관련 컴포넌트 목 처리
    @MockBean
    private JointOrderRequestRepository jointOrderRequestRepository;

    @MockBean
    private JointOrderService jointOrderService;

    @MockBean
    private JointOrderTimeoutService jointOrderTimeoutService;

    // Places 관련 컴포넌트 목 처리
    @MockBean
    private PlacesRepository placesRepository;

    // Notification 관련 컴포넌트 목 처리
    @MockBean
    private NotificationSendHistoryRepository notificationSendHistoryRepository;

	@Test
	void contextLoads() {
	}

}
