package com.example.capstone.repository;

import com.example.capstone.domain.settlement.DeliverySettlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;

public interface DeliverySettlementRepository extends JpaRepository<DeliverySettlement, Long> {

    @Query("select count(distinct ds.cart.id) as totalOrders, " +
           "coalesce(sum(ds.originalDeliveryFee), 0) as originalDeliveryFee, " +
           "coalesce(sum(ds.paidDeliveryFee), 0) as paidDeliveryFee, " +
           "coalesce(sum(ds.savedDeliveryFee), 0) as savedDeliveryFee " +
           "from DeliverySettlement ds where ds.user.id = :userId")
    DeliverySettlementAggregate aggregateByUser(@Param("userId") Long userId);

    List<DeliverySettlement> findByCart_Id(Long cartId);

    List<DeliverySettlement> findByCart_IdAndUser_Id(Long cartId, Long userId);

    interface DeliverySettlementAggregate {
        Long getTotalOrders();
        BigDecimal getOriginalDeliveryFee();
        BigDecimal getPaidDeliveryFee();
        BigDecimal getSavedDeliveryFee();
    }
}
